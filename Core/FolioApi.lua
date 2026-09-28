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
  for _, node_id in ipairs(C_Traits.GetTreeNodes(TREE_ID)) do
    local info = C_Traits.GetNodeInfo(config_id, node_id)
    if info and info.entryIDs and #info.entryIDs > 1 then
      nodes[node_id] = info
    end
  end
  return nodes
end

local function active_entry_id(info)
  return info.activeEntry and info.activeEntry.entryID
end

local function entry_name(config_id, entry_id)
  local entry = C_Traits.GetEntryInfo(config_id, entry_id)
  local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
  if not definition then return "?" end
  return definition.overrideName or (definition.spellID and C_Spell.GetSpellName(definition.spellID)) or "?"
end

-- Ergebnis: "applied", "unchanged" oder ein Grund zum Überspringen.
local function apply_selection(config_id, info, node_id, entry_id)
  if not info or not util.contains(info.entryIDs, entry_id) then return "unknown" end
  if active_entry_id(info) == entry_id then return "unchanged" end
  if not info.isAvailable then return "locked" end
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
    selections[node_id] = active_entry_id(info)
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

function folio_api.apply(selections)
  local result = { applied = {}, skipped = {} }
  local config_id = current_config_id()
  if not config_id then
    result.reason = "unavailable"
    return result
  end

  local nodes = choice_nodes(config_id)
  for _, node_id in ipairs(util.sorted_keys(selections)) do
    local outcome = apply_selection(config_id, nodes[node_id], node_id, selections[node_id])
    if outcome == "applied" then
      table.insert(result.applied, node_id)
    elseif outcome ~= "unchanged" then
      table.insert(result.skipped, { node_id = node_id, reason = outcome })
    end
  end

  if #result.applied > 0 and not C_Traits.CommitConfig(config_id) then
    result.reason = "commit_failed"
  end
  return result
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
