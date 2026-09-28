local _, ns = ...

local util = {}
ns.util = util

function util.sorted_keys(map)
  local keys = {}
  for key in pairs(map) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

function util.contains(list, value)
  for _, item in ipairs(list) do
    if item == value then return true end
  end
  return false
end

function util.copy(map)
  local result = {}
  for key, value in pairs(map) do
    result[key] = value
  end
  return result
end
