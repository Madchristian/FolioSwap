local _, ns = ...
local util = ns.util

-- Werte aus Blizzard_MidnightLandingPage.lua (Build 12.1.0): intern heißt der Omniumfoliant "Runes of Power".
local SYSTEM_ID = 48
local TREE_ID = 1186

local folio_api = {}
ns.folio_api = folio_api

local function current_config_id()
  return C_Traits.GetConfigIDBySystemID(SYSTEM_ID)
end

-- Nur Nodes mit echter Auswahl; die Reihe ohne Wahl (Rune of Lingering) fällt heraus.
local function choice_nodes(config_id)
  local nodes = {}
  for _, node_id in ipairs(C_Traits.GetTreeNodes(TREE_ID) or {}) do
    local info = C_Traits.GetNodeInfo(config_id, node_id)
    if info and info.entryIDs and #info.entryIDs > 1 then
      nodes[node_id] = info
    end
  end
  return nodes
end

local function committed_entry_id(info)
  return info.entryIDsWithCommittedRanks and info.entryIDsWithCommittedRanks[1]
end

local function entry_name(config_id, entry_id)
  local entry = C_Traits.GetEntryInfo(config_id, entry_id)
  local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
  if not definition then return "?" end
  return definition.overrideName or (definition.spellID and C_Spell.GetSpellName(definition.spellID)) or "?"
end

-- Reine Entscheidung ohne Seiteneffekt (kein SetSelection) - von apply_selection UND
-- pending_changes genutzt, damit beide sich nicht widersprechen können (DRY).
-- "pending" heißt: aktueller und gewünschter Eintrag existieren beide und weichen voneinander ab -
-- erst dann versucht apply_selection tatsächlich SetSelection. Ein Tausch zwischen bereits
-- gewählten Runen ist unabhängig von isAvailable erlaubt (wie Blizzards CanSelectChoice); nur der
-- Erstkauf eines unbelegten Nodes wird nie ungefragt ausgelöst, weil er Foliant-Währung kostet.
local function decide_selection(info, entry_id)
  if not info or not util.contains(info.entryIDs, entry_id) then return "unknown" end
  if committed_entry_id(info) == entry_id then return "unchanged" end
  if not committed_entry_id(info) then
    if not info.isAvailable then return "locked" end
    return "unpurchased"
  end
  return "pending"
end

-- Ergebnis: "applied", "unchanged" oder ein Grund zum Überspringen.
local function apply_selection(config_id, info, node_id, entry_id)
  local decision = decide_selection(info, entry_id)
  if decision ~= "pending" then return decision end
  if C_Traits.SetSelection(config_id, node_id, entry_id) then return "applied" end
  return "rejected"
end

function folio_api.is_available()
  return current_config_id() ~= nil
end

function folio_api.read_current()
  local config_id = current_config_id()
  if not config_id then return nil end
  local selections = {}
  for node_id, info in pairs(choice_nodes(config_id)) do
    local committed = info.entryIDsWithCommittedRanks
    if not committed then return nil end
    selections[node_id] = committed[1]
  end
  return selections
end

function folio_api.catalog()
  local config_id = current_config_id()
  if not config_id then return nil end
  local catalog = {}
  for node_id, info in pairs(choice_nodes(config_id)) do
    catalog[node_id] = info.entryIDs
  end
  return catalog
end

-- Read-only completion check, bound to the submitted config and requested non-skipped rows.
-- CommitConfig(true) is acceptance, not completion; activeEntry includes staged selections.
-- Require readiness, no staged changes, and matching entryIDsWithCommittedRanks. Trait events
-- are deliberately not used as acknowledgements (see docs/trait-commit-contract.md).
-- Never roll back or resubmit after acceptance: a newer manual edit may own the config.
function folio_api.verify(result)
  local pending = result.pending
  if current_config_id() ~= pending.config_id then
    return { applied = {}, skipped = result.skipped, reason = "commit_failed" }
  end
  if not C_Traits.IsReadyForCommit() or C_Traits.ConfigHasStagedChanges(pending.config_id) then return result end
  for node_id, entry_id in pairs(pending.selections) do
    local info = C_Traits.GetNodeInfo(pending.config_id, node_id)
    local committed = info and info.entryIDsWithCommittedRanks
    if not committed or #committed ~= 1 or committed[1] ~= entry_id then
      return { applied = {}, skipped = result.skipped, reason = "commit_failed" }
    end
  end
  return { applied = pending.changed, skipped = result.skipped }
end

-- result = { applied = {confirmed changed node IDs}, skipped = {{node_id, reason, entry_id, name?}},
-- reason = nil | unavailable | busy | cannot_edit | commit_failed | pending, pending = token? }.
-- Pending results have no applied nodes. Actions polls verify(), with a bounded timeout.
-- Skip reasons: unknown | locked | unpurchased | rejected. Unknown entries have no name.
-- Refuse pre-existing staged edits; only a synchronously rejected submission is rolled back.
function folio_api.apply(selections)
  local result = { applied = {}, skipped = {} }
  local config_id = current_config_id()
  if not config_id then
    result.reason = "unavailable"
    return result
  end
  if not C_Traits.IsReadyForCommit() then
    result.reason = "busy"
    return result
  end
  if not C_Traits.CanEditConfig(config_id) or C_Traits.ConfigHasStagedChanges(config_id) then
    result.reason = "cannot_edit"
    return result
  end

  local nodes = choice_nodes(config_id)
  local expected = {}
  for _, node_id in ipairs(util.sorted_keys(selections)) do
    local outcome = apply_selection(config_id, nodes[node_id], node_id, selections[node_id])
    if outcome == "applied" or outcome == "unchanged" then
      expected[node_id] = selections[node_id]
      if outcome == "applied" then table.insert(result.applied, node_id) end
    else
      local skip = { node_id = node_id, reason = outcome, entry_id = selections[node_id] }
      -- Bei "unknown" ist der entry_id im Baum nicht auffindbar - kein Name zu ermitteln.
      if outcome ~= "unknown" then
        skip.name = entry_name(config_id, selections[node_id])
      end
      table.insert(result.skipped, skip)
    end
  end

  if #result.applied > 0 then
    local changed = result.applied
    result.applied = {}
    if not C_Traits.CommitConfig(config_id) then
      C_Traits.RollbackConfig(config_id)
      result.reason = "commit_failed"
    else
      result.reason = "pending"
      result.pending = { config_id = config_id, selections = expected, changed = changed }
      return folio_api.verify(result)
    end
  end
  return result
end

-- Nur lesend (kein SetSelection): welche Nodes apply(selections) tatsächlich umzustellen
-- versuchen würde. Für actions.needs_apply(), damit gesperrte/unbezahlte/unbekannte Abweichungen
-- keine Kampf-Vormerkung auslösen - nutzt dieselbe Entscheidung wie apply_selection (DRY).
function folio_api.pending_changes(selections)
  local config_id = current_config_id()
  if not config_id then return nil end
  local nodes = choice_nodes(config_id)
  local changes = {}
  for _, node_id in ipairs(util.sorted_keys(selections)) do
    if decide_selection(nodes[node_id], selections[node_id]) == "pending" then
      changes[#changes + 1] = node_id
    end
  end
  return changes
end

function folio_api.dump()
  local config_id = current_config_id()
  if not config_id then return nil end
  local nodes = choice_nodes(config_id)
  local rows = {}
  for _, node_id in ipairs(util.sorted_keys(nodes)) do
    local entries = {}
    for _, entry_id in ipairs(nodes[node_id].entryIDs) do
      entries[#entries + 1] = { entry_id = entry_id, name = entry_name(config_id, entry_id) }
    end
    rows[#rows + 1] = { node_id = node_id, entries = entries }
  end
  return rows
end
