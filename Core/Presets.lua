local _, ns = ...
local util = ns.util

local presets = {}
ns.presets = presets

-- Guide-Empfehlungen: [spec_id] = { { name = "...", selections = { [node_id] = entry_id } } }
-- Die IDs stammen aus /folio dump; Quellen und Pflege stehen in docs/presets.md.
presets.data = {}

function presets.for_spec(spec_id)
  local profiles = {}
  for _, preset in ipairs(presets.data[spec_id] or {}) do
    profiles[#profiles + 1] = { name = preset.name, source = "preset", selections = preset.selections }
  end
  return profiles
end

function presets.find(spec_id, name)
  for _, profile in ipairs(presets.for_spec(spec_id)) do
    if profile.name == name then return profile end
  end
  return nil
end

-- catalog: [node_id] = { entry_id, ... } aus folio_api.catalog()
function presets.validate(catalog)
  local problems = {}
  for _, spec_id in ipairs(util.sorted_keys(presets.data)) do
    for _, preset in ipairs(presets.data[spec_id]) do
      for _, node_id in ipairs(util.sorted_keys(preset.selections)) do
        local entry_id = preset.selections[node_id]
        if not util.contains(catalog[node_id] or {}, entry_id) then
          problems[#problems + 1] = { spec_id = spec_id, name = preset.name, node_id = node_id, entry_id = entry_id }
        end
      end
    end
  end
  return problems
end
