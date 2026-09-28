local wow_env = require("spec.helpers.wow_env")

local LOCKED_FOLIO = { config_id = nil, nodes = {} }

describe("folio_api", function()
  local env, api
  before_each(function()
    env = wow_env.new()
    api = env.ns.folio_api
  end)

  it("ist ohne Config-ID nicht verfügbar", function()
    local locked = wow_env.new({ tree = LOCKED_FOLIO }).ns.folio_api
    assert.is_false(locked.is_available())
    assert.is_nil(locked.read_current())
    assert.is_nil(locked.catalog())
    assert.is_nil(locked.dump())
    assert.equals("unavailable", locked.apply({ [100] = 1002 }).reason)
  end)

  it("ist mit Config-ID verfügbar", function()
    assert.is_true(api.is_available())
  end)

  it("liest nur Nodes mit echter Auswahl und gesetzter Rune", function()
    assert.same({ [100] = 1001, [200] = 2001, [400] = 4001 }, api.read_current())
  end)

  it("liefert den Katalog aller Auswahl-Nodes", function()
    local catalog = api.catalog()
    assert.same({ 4001, 4002, 4003, 4004 }, catalog[400])
    assert.same({ 5001, 5002, 5003 }, catalog[500])
    assert.is_nil(catalog[300])
  end)

  it("setzt nur abweichende Runen und committet einmal", function()
    local result = api.apply({ [100] = 1002, [200] = 2001, [400] = 4003 })
    assert.same({ 100, 400 }, result.applied)
    assert.same({}, result.skipped)
    assert.is_nil(result.reason)
    assert.same({ { 100, 1002 }, { 400, 4003 } }, env.traits.set_calls)
    assert.equals(1, env.traits.commits)
  end)

  it("committet nicht, wenn alles schon passt", function()
    local result = api.apply({ [100] = 1001 })
    assert.same({}, result.applied)
    assert.same({}, result.skipped)
    assert.equals(0, env.traits.commits)
  end)

  it("überspringt unbekannte, gesperrte und abgelehnte Runen", function()
    env.traits.reject[200] = true
    local result = api.apply({ [100] = 9999, [200] = 2002, [500] = 5001, [777] = 1 })
    assert.same({
      { node_id = 100, reason = "unknown" },
      { node_id = 200, reason = "rejected" },
      { node_id = 500, reason = "locked" },
      { node_id = 777, reason = "unknown" },
    }, result.skipped)
    assert.equals(0, env.traits.commits)
  end)

  it("meldet einen fehlgeschlagenen Commit", function()
    env.traits.commit_ok = false
    assert.equals("commit_failed", api.apply({ [100] = 1002 }).reason)
  end)

  it("gibt beim Dump Nodes, Entries und Runennamen aus", function()
    local rows = api.dump()
    assert.equals(4, #rows)
    assert.equals(100, rows[1].node_id)
    assert.same({ entry_id = 1001, name = "Spell 100100" }, rows[1].entries[1])
  end)
end)
