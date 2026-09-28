local wow_env = require("spec.helpers.wow_env")

describe("slash_commands", function()
  local env
  before_each(function() env = wow_env.new() end)

  it("registriert /folio und /folioswap", function()
    assert.equals(env.ns.slash_commands.handle, SlashCmdList.FOLIOSWAP)
    assert.equals("/folio", SLASH_FOLIOSWAP1)
    assert.equals("/folioswap", SLASH_FOLIOSWAP2)
  end)

  it("reicht Profilnamen mit Leerzeichen durch", function()
    SlashCmdList.FOLIOSWAP("save  Mein M+ Setup  ")
    assert.is_table(env.ns.profile_store.get(62, "Mein M+ Setup"))
  end)

  it("ignoriert Groß- und Kleinschreibung beim Befehl", function()
    SlashCmdList.FOLIOSWAP("SAVE Mein")
    SlashCmdList.FOLIOSWAP("LIST")
    assert.equals("  Mein", env.messages[#env.messages])
  end)

  it("zeigt bei unbekannten oder leeren Befehlen die Hilfe", function()
    SlashCmdList.FOLIOSWAP("quatsch")
    assert.matches("/folio list", env.messages[#env.messages])
    SlashCmdList.FOLIOSWAP("")
    assert.equals(2, #env.messages)
  end)
end)
