local _, ns = ...
local L = ns.L
local util = ns.util
local folio_api = ns.folio_api
local presets = ns.presets
local profile_store = ns.profile_store
local player = ns.player
local reporter = ns.reporter

-- Gemeinsame Anwendungsfälle für Slash-Befehle, Panel und Automatik.
-- Completion is read-only and bounded independently of the controller's pre-submit retries.
-- A timeout is uncertainty, not proof of rejection; never resubmit/rollback from this watcher.
local COMMIT_POLL_DELAY = 0.5
local MAX_COMMIT_POLLS = 20
local apply_generation = 0
local actions = {}
ns.actions = actions

local function with_spec(handler)
  return function(...)
    local spec_id = player.current_spec_id()
    if not spec_id then return reporter.say(L.no_spec) end
    return handler(spec_id, ...)
  end
end

-- Wie with_spec, normalisiert zusätzlich den Profilnamen: leer (oder kein String, z.B. nil)
-- bricht mit einer Rückmeldung ab, statt später mit nil in ein string.format zu crashen.
local function with_profile_name(handler)
  return with_spec(function(spec_id, name)
    name = util.trim(name)
    if name == "" then return reporter.say(L.empty_name) end
    return handler(spec_id, name)
  end)
end

-- FolioPanel wird nur ingame geladen (in Tests nicht Teil der .toc-Dateiliste) - daher die Prüfung.
local function refresh_panel()
  if ns.folio_panel then ns.folio_panel.refresh() end
end

local function say_result(ok, err, success_text, name)
  reporter.say(ok and success_text:format(name) or L[err]:format(name))
  refresh_panel()
  return ok
end

function actions.cancel_pending()
  apply_generation = apply_generation + 1
end

local function apply_profile(profile, verbose)
  actions.cancel_pending()
  local generation = apply_generation
  local spec_id = player.current_spec_id()
  profile = { name = profile.name, source = profile.source, selections = util.copy(profile.selections) }
  local result = folio_api.apply(profile.selections)
  local polls = 0
  local function report_completion()
    if generation ~= apply_generation or player.current_spec_id() ~= spec_id then return end
    local current = profile_store.get(spec_id, profile.name)
    if not current or current.source ~= profile.source then return end
    for node_id, entry_id in pairs(profile.selections) do
      if current.selections[node_id] ~= entry_id then return end
    end
    for node_id, entry_id in pairs(current.selections) do
      if profile.selections[node_id] ~= entry_id then return end
    end
    if not verbose and profile_store.active_name(spec_id) ~= profile.name then return end
    polls = polls + 1
    result = folio_api.verify(result)
    if result.pending and polls >= MAX_COMMIT_POLLS then
      result = { applied = {}, skipped = result.skipped, reason = "commit_timeout" }
    end
    if result.pending then
      C_Timer.After(COMMIT_POLL_DELAY, report_completion)
    else
      reporter.report_apply(profile, result, verbose)
      refresh_panel()
    end
  end
  if result.pending then
    C_Timer.After(COMMIT_POLL_DELAY, report_completion)
  else
    reporter.report_apply(profile, result, verbose)
  end
  return result
end

actions.apply = with_profile_name(function(spec_id, name)
  if InCombatLockdown() then return reporter.say(L.in_combat) end
  local profile = profile_store.get(spec_id, name)
  if not profile then return reporter.say(L.not_found:format(name)) end
  ns.swap_controller.cancel_retry()
  apply_profile(profile, true)
  refresh_panel()
end)

actions.save_current = with_profile_name(function(spec_id, name)
  local selections = folio_api.read_current()
  if not selections then return reporter.report_unavailable(true) end
  local ok, err = profile_store.save(spec_id, name, selections)
  return say_result(ok, err, L.saved, name)
end)

actions.delete = with_profile_name(function(spec_id, name)
  local ok, err = profile_store.delete(spec_id, name)
  return say_result(ok, err, L.deleted, name)
end)

actions.set_active = with_profile_name(function(spec_id, name)
  local ok, err = profile_store.set_active(spec_id, name)
  return say_result(ok, err, L.activated, name)
end)

actions.list = with_spec(function(spec_id)
  local profiles = profile_store.list(spec_id)
  if #profiles == 0 then return reporter.say(L.no_profiles) end
  local active_name = profile_store.active_name(spec_id)
  reporter.say(L.list_header)
  for _, profile in ipairs(profiles) do
    reporter.say_line("  " .. reporter.profile_label(profile, active_name))
  end
end)

-- Automatik: leise, solange nichts umgestellt werden muss. Liefert das Ergebnis (oder nil ohne Profil),
-- damit der SwapController bei "busy" erneut versuchen kann.
function actions.apply_active()
  local spec_id = player.current_spec_id()
  local profile = spec_id and profile_store.get_active(spec_id)
  if not profile then return nil end
  return apply_profile(profile, false)
end

-- Für die Kampf-Vormerkung: true, wenn eine Spec und ein aktives Profil existieren und
-- FolioApi.apply für dieses Profil tatsächlich etwas umstellen würde (oder der Foliant gerade
-- nicht lesbar ist). Nutzt dieselbe Entscheidung wie apply(), statt sie zu duplizieren (DRY) -
-- so lösen rein gesperrte/unbezahlte/unbekannte Abweichungen keine Vormerkung aus.
function actions.needs_apply()
  local spec_id = player.current_spec_id()
  local profile = spec_id and profile_store.get_active(spec_id)
  if not profile then return false end
  local changes = folio_api.pending_changes(profile.selections)
  if not changes then return true end
  return #changes > 0
end

function actions.dump()
  local rows = folio_api.dump()
  if not rows then return reporter.report_unavailable(true) end
  profile_store.db.dump = rows
  reporter.say(L.dump_saved:format(#rows))
end

function actions.check()
  local catalog = folio_api.catalog()
  if not catalog then return reporter.report_unavailable(true) end
  local problems = presets.validate(catalog)
  if #problems == 0 then return reporter.say(L.check_ok) end
  for _, problem in ipairs(problems) do
    reporter.say(L.check_problem:format(problem.name, problem.spec_id, problem.node_id, problem.entry_id))
  end
end

function actions.help()
  reporter.say(L.help)
end
