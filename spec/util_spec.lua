local wow_env = require("spec.helpers.wow_env")

describe("util", function()
  local util
  before_each(function() util = wow_env.new().ns.util end)

  it("sortiert Schlüssel", function()
    assert.same({ 1, 2, 10 }, util.sorted_keys({ [10] = "a", [1] = "b", [2] = "c" }))
    assert.same({ "Alpha", "Zeta" }, util.sorted_keys({ Zeta = true, Alpha = true }))
  end)

  it("findet Werte in Listen", function()
    assert.is_true(util.contains({ 1, 2, 3 }, 2))
    assert.is_false(util.contains({ 1, 2, 3 }, 4))
  end)

  it("kopiert Tabellen flach", function()
    local original = { [100] = 1001 }
    local copy = util.copy(original)
    original[100] = 1002
    assert.same({ [100] = 1001 }, copy)
  end)

  it("trimmt Strings und liefert einen leeren String für Nicht-Strings", function()
    assert.equals("Mein", util.trim("  Mein  "))
    assert.equals("", util.trim("   "))
    assert.equals("", util.trim(nil))
    assert.equals("", util.trim(42))
  end)
end)
