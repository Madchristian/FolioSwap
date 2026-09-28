local _, ns = ...
local util = ns.util
local presets = ns.presets

local DB_VERSION = 1

local profile_store = {}
ns.profile_store = profile_store

-- Verwirft grob kaputte SavedVariables-Daten, statt daran zu crashen: falsche Typen für
-- profiles/active, Profile ohne table-selections, nicht-string Profil-Schlüssel und
-- nicht-string active-Einträge fallen raus. Gültige Profile bekommen name/source normalisiert,
-- damit sortierte Ausgaben (list) sich auf beides verlassen können.
local function sanitize(db)
  if type(db.profiles) ~= "table" then db.profiles = {} end
  if type(db.active) ~= "table" then db.active = {} end
  for spec_id, own in pairs(db.profiles) do
    if type(own) ~= "table" then
      db.profiles[spec_id] = nil
    else
      for name, profile in pairs(own) do
        if type(name) ~= "string" or type(profile) ~= "table" or type(profile.selections) ~= "table" then
          own[name] = nil
        else
          profile.name = name
          profile.source = "user"
        end
      end
    end
  end
  for spec_id, name in pairs(db.active) do
    if type(name) ~= "string" then
      db.active[spec_id] = nil
    end
  end
end

-- Erster freier Name für ein eigenes Profil, das mit einem Preset kollidiert
-- (frei = weder eigenes Profil noch Preset).
local function first_free_name(spec_id, own, name)
  local candidate, suffix = name, 2
  while presets.find(spec_id, candidate) or own[candidate] do
    candidate = name .. " (" .. suffix .. ")"
    suffix = suffix + 1
  end
  return candidate
end

-- Liefert ein Guide-Update später ein Preset unter einem Namen aus, den der Spieler schon für
-- ein eigenes Profil vergeben hat, wird das eigene Profil umbenannt (Presets sind schreibgeschützt).
-- Zeigte das aktive Profil auf den alten Namen, wandert es mit um.
local function resolve_preset_collisions(db)
  for spec_id, own in pairs(db.profiles) do
    for _, name in ipairs(util.sorted_keys(own)) do
      local profile = own[name]
      if profile and presets.find(spec_id, name) then
        local new_name = first_free_name(spec_id, own, name)
        own[name] = nil
        profile.name = new_name
        own[new_name] = profile
        if db.active[spec_id] == name then
          db.active[spec_id] = new_name
        end
      end
    end
  end
end

function profile_store.init(db)
  db = db or {}
  db.version = db.version or DB_VERSION
  sanitize(db)
  resolve_preset_collisions(db)
  profile_store.db = db
  return db
end

local function own_profiles(spec_id)
  return profile_store.db.profiles[spec_id] or {}
end

-- Zurückgegebene Profile (list/get) nicht verändern – eigene Profile sind die Tabellen aus FolioSwapDB.
function profile_store.list(spec_id)
  local list = presets.for_spec(spec_id)
  local own = own_profiles(spec_id)
  for _, name in ipairs(util.sorted_keys(own)) do
    list[#list + 1] = own[name]
  end
  return list
end

function profile_store.get(spec_id, name)
  return presets.find(spec_id, name) or own_profiles(spec_id)[name]
end

function profile_store.save(spec_id, name, selections)
  if type(name) ~= "string" then return false, "empty_name" end
  name = name:match("^%s*(.-)%s*$")
  if name == "" then return false, "empty_name" end
  if presets.find(spec_id, name) then return false, "preset_name" end
  local profiles = profile_store.db.profiles
  profiles[spec_id] = profiles[spec_id] or {}
  profiles[spec_id][name] = { name = name, source = "user", selections = util.copy(selections) }
  return true
end

function profile_store.delete(spec_id, name)
  if presets.find(spec_id, name) then return false, "preset_readonly" end
  local own = own_profiles(spec_id)
  if not own[name] then return false, "not_found" end
  own[name] = nil
  if profile_store.db.active[spec_id] == name then
    profile_store.db.active[spec_id] = nil
  end
  return true
end

function profile_store.set_active(spec_id, name)
  if not profile_store.get(spec_id, name) then return false, "not_found" end
  profile_store.db.active[spec_id] = name
  return true
end

-- Ohne gültiges aktives Profil gilt das erste Preset der Spec.
function profile_store.active_name(spec_id)
  local name = profile_store.db.active[spec_id]
  if name and profile_store.get(spec_id, name) then return name end
  local first_preset = presets.for_spec(spec_id)[1]
  return first_preset and first_preset.name
end

function profile_store.get_active(spec_id)
  local name = profile_store.active_name(spec_id)
  return name and profile_store.get(spec_id, name)
end
