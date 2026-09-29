local wow_env = require("spec.helpers.wow_env")

describe("player", function()
  it("liefert die specID der aktiven Spezialisierung", function()
    assert.equals(62, wow_env.new({ spec_id = 62 }).ns.player.current_spec_id())
  end)

  it("liefert nil ohne Spezialisierung", function()
    local env = wow_env.new()
    env.spec_id = nil
    assert.is_nil(env.ns.player.current_spec_id())
  end)
end)
