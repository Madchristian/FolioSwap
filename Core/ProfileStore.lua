local _, ns = ...
local util = ns.util
local presets = ns.presets

local DB_VERSION = 1

local profile_store = {}
ns.profile_store = profile_store

function profile_store.init(db)
  db = db or {}
  db.version = db.version or DB_VERSION
  db.profiles = db.profiles or {}
  db.active = db.active or {}
  profile_store.db = db
  return db
end

local function own_profiles(spec_id)
  return profile_store.db.profiles[spec_id] or {}
end

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
  if not name or name == "" then return false, "empty_name" end
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
