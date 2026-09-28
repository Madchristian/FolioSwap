local _, ns = ...
local L = ns.L
local util = ns.util
local folio_api = ns.folio_api
local presets = ns.presets
local profile_store = ns.profile_store
local player = ns.player
local reporter = ns.reporter

-- Gemeinsame Anwendungsfälle für Slash-Befehle, Panel und Automatik.
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

local function apply_profile(profile, verbose)
  local result = folio_api.apply(profile.selections)
  reporter.report_apply(profile, result, verbose)
  return result
end

actions.apply = with_profile_name(function(spec_id, name)
  if InCombatLockdown() then return reporter.say(L.in_combat) end
  local profile = profile_store.get(spec_id, name)
  if not profile then return reporter.say(L.not_found:format(name)) end
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

-- Für die Kampf-Vormerkung: true, wenn eine Spec und ein aktives Profil existieren und entweder
-- der aktuelle Zustand unbekannt ist oder mindestens eine Auswahl des Profils abweicht.
function actions.needs_apply()
  local spec_id = player.current_spec_id()
  local profile = spec_id and profile_store.get_active(spec_id)
  if not profile then return false end
  local current = folio_api.read_current()
  if not current then return true end
  for node_id, entry_id in pairs(profile.selections) do
    if current[node_id] ~= entry_id then return true end
  end
  return false
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
