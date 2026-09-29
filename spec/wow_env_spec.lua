local wow_env = require("spec.helpers.wow_env")

describe("wow_env", function()
  it("stellt den Foliant-Mock bereit", function()
    local env = wow_env.new()
    assert.equals(7, C_Traits.GetConfigIDBySystemID(48))
    assert.same({ 100, 200, 300, 400, 500 }, C_Traits.GetTreeNodes(1186))
    assert.is_table(env.ns)
  end)

  it("übernimmt Kampf- und Spec-Zustand live", function()
    local env = wow_env.new()
    env.in_combat = true
    env.spec_id = 63
    assert.is_true(InCombatLockdown())
    assert.equals(63, GetSpecializationInfo(GetSpecialization()))
  end)
end)
