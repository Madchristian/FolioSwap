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
    assert.equals(0, env.traits.rollbacks)
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
      { node_id = 100, reason = "unknown", entry_id = 9999 },
      { node_id = 200, reason = "rejected", entry_id = 2002, name = "Spell 200200" },
      { node_id = 500, reason = "locked", entry_id = 5001, name = "Spell 500100" },
      { node_id = 777, reason = "unknown", entry_id = 1 },
    }, result.skipped)
    assert.same({ { 200, 2002 } }, env.traits.set_calls)
    assert.equals(0, env.traits.commits)
  end)

  it("kauft einen unbelegten, verfügbaren Node nicht ungefragt", function()
    local unpurchased = wow_env.new({ tree = { config_id = 7, nodes = { { id = 600, entries = { 6001, 6002 } } } } })
    local result = unpurchased.ns.folio_api.apply({ [600] = 6001 })
    assert.same({ { node_id = 600, reason = "unpurchased", entry_id = 6001, name = "Spell 600100" } }, result.skipped)
    assert.same({}, unpurchased.traits.set_calls)
  end)

  it("erlaubt den Tausch bei einem belegten, aber gesperrten Node", function()
    local locked = wow_env.new({
      tree = { config_id = 7, nodes = { { id = 700, entries = { 7001, 7002 }, active = 7001, available = false } } },
    })
    local result = locked.ns.folio_api.apply({ [700] = 7002 })
    assert.same({ 700 }, result.applied)
  end)

  it("meldet busy, wenn das Spiel gerade speichert", function()
    env.traits.ready = false
    local result = api.apply({ [100] = 1002 })
    assert.equals("busy", result.reason)
    assert.same({}, env.traits.set_calls)
  end)

  it("meldet cannot_edit, wenn die Config gerade nicht bearbeitbar ist", function()
    env.traits.can_edit = false
    assert.equals("cannot_edit", api.apply({ [100] = 1002 }).reason)
  end)

  it("meldet einen fehlgeschlagenen Commit und rollt zurück", function()
    env.traits.commit_ok = false
    local result = api.apply({ [100] = 1002 })
    assert.equals("commit_failed", result.reason)
    assert.equals(1, env.traits.rollbacks)
    assert.same({}, result.applied)
  end)

  it("behandelt eine fehlende Tree-Nodes-Liste als leer", function()
    C_Traits.GetTreeNodes = function() return nil end
    assert.same({}, api.read_current())
  end)

  it("gibt beim Dump Nodes, Entries und Runennamen aus", function()
    local rows = api.dump()
    assert.equals(4, #rows)
    assert.equals(100, rows[1].node_id)
    assert.same({ entry_id = 1001, name = "Spell 100100" }, rows[1].entries[1])
  end)

  describe("pending_changes", function()
    it("ist ohne Config-ID nil", function()
      local locked = wow_env.new({ tree = LOCKED_FOLIO }).ns.folio_api
      assert.is_nil(locked.pending_changes({ [100] = 1002 }))
    end)

    it("ist leer, wenn schon alles passt", function()
      assert.same({}, api.pending_changes({ [100] = 1001 }))
    end)

    it("nennt nur Nodes, für die apply tatsächlich SetSelection versuchen würde", function()
      local changes = api.pending_changes({ [100] = 1002, [500] = 5001, [777] = 1 })
      assert.same({ 100 }, changes)
      -- rein lesend: kein SetSelection-Aufruf.
      assert.same({}, env.traits.set_calls)
    end)

    it("zählt gesperrte, unbezahlte und unbekannte Abweichungen nicht als anstehende Änderung", function()
      local unpurchased = wow_env.new({ tree = { config_id = 7, nodes = { { id = 600, entries = { 6001, 6002 } } } } })
      assert.same({}, unpurchased.ns.folio_api.pending_changes({ [600] = 6001 }))
    end)
  end)
end)
