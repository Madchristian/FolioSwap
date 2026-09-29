local _, ns = ...

local skin = {}
ns.skin = skin
skin.accents = {
  teal = { 0.25, 0.82, 0.73 }, blue = { 0.35, 0.66, 1 },
  violet = { 0.73, 0.55, 1 }, amber = { 1, 0.73, 0.32 },
}

local function number(value, fallback, low, high)
  if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
    return fallback
  end
  return math.max(low, math.min(high, value))
end

function skin.normalize(value)
  value = type(value) == "table" and value or {}
  return {
    accent = type(value.accent) == "string" and skin.accents[value.accent] and value.accent or "teal",
    opacity = number(value.opacity, 0.94, 0.65, 1),
    scale = number(value.scale, 1, 0.8, 1.25),
  }
end

function skin.get()
  local db = ns.profile_store.db
  return db and db.skin or skin.normalize()
end

function skin.set(key, value)
  if key ~= "accent" and key ~= "opacity" and key ~= "scale" then return end
  local db = ns.profile_store.db
  if not db then return end
  local candidate = ns.util.copy(db.skin)
  candidate[key] = value
  db.skin = skin.normalize(candidate)
  if skin.refresh then skin.refresh() end
end

function skin.reset()
  if not ns.profile_store.db then return end
  ns.profile_store.db.skin = skin.normalize()
  if skin.refresh then skin.refresh() end
end
