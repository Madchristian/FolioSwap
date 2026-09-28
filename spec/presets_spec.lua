local wow_env = require("spec.helpers.wow_env")

local function sample_presets()
  return {
    [62] = { { name = "Guide M+", selections = { [100] = 1002, [400] = 4003 } } },
    [63] = { { name = "Guide Raid", selections = { [100] = 1001, [900] = 9001 } } },
  }
end

describe("presets", function()
  local env, presets
  before_each(function()
    env = wow_env.new({ presets = sample_presets() })
    presets = env.ns.presets
  end)

  it("liefert die Presets einer Spec als schreibgeschützte Profile", function()
    local list = presets.for_spec(62)
    assert.equals(1, #list)
    assert.equals("Guide M+", list[1].name)
    assert.equals("preset", list[1].source)
    assert.equals(1002, list[1].selections[100])
  end)

  it("liefert eine leere Liste für Specs ohne Presets", function()
    assert.same({}, presets.for_spec(64))
  end)

  it("findet Presets per Name", function()
    assert.equals("Guide M+", presets.find(62, "Guide M+").name)
    assert.is_nil(presets.find(62, "Gibt es nicht"))
  end)

  it("meldet Einträge, die nicht im Foliant vorkommen", function()
    assert.same(
      { { spec_id = 63, name = "Guide Raid", node_id = 900, entry_id = 9001 } },
      presets.validate(env.ns.folio_api.catalog())
    )
  end)

  it("ausgelieferte Presets haben pro Spec eindeutige, nicht leere Namen", function()
    for spec_id, list in pairs(wow_env.new().ns.presets.data) do
      local seen = {}
      for _, preset in ipairs(list) do
        assert.is_true(type(preset.name) == "string" and preset.name ~= "", "Name fehlt in Spec " .. spec_id)
        assert.is_nil(seen[preset.name], "Doppelter Name " .. tostring(preset.name))
        assert.is_table(preset.selections)
        seen[preset.name] = true
      end
    end
  end)
end)
