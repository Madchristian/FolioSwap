local wow_env = require("spec.helpers.wow_env")

describe("Locales", function()
  it("liefert englische Texte als Standard", function()
    assert.equals("Apply", wow_env.new().ns.L.panel_apply)
  end)

  it("überschreibt Texte auf deDE", function()
    assert.equals("Anwenden", wow_env.new({ locale = "deDE" }).ns.L.panel_apply)
  end)

  it("fällt bei fehlenden Schlüsseln auf den Schlüssel zurück", function()
    assert.equals("does_not_exist", wow_env.new().ns.L.does_not_exist)
  end)

  it("übersetzt alle Texte ins Deutsche", function()
    local en = wow_env.new().ns.L
    local de = wow_env.new({ locale = "deDE" }).ns.L
    local same_in_both = {
      prefix = true, preset_marker = true, panel_skin = true, skin_foliant = true, skin_flat = true,
    }
    for key, text in pairs(en) do
      if not same_in_both[key] then
        assert.are_not.equal(text, de[key], key)
      end
    end
  end)

  it("behält Format-Platzhalter in Anzahl und Reihenfolge bei", function()
    local en = wow_env.new().ns.L
    local de = wow_env.new({ locale = "deDE" }).ns.L
    local function placeholders(text)
      local list = {}
      for placeholder in text:gmatch("%%%a") do list[#list + 1] = placeholder end
      return table.concat(list, ",")
    end
    for key, text in pairs(en) do
      assert.equals(placeholders(text), placeholders(de[key]), key)
    end
  end)
end)
