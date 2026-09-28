local wow_env = require("spec.helpers.wow_env")

local function sample_presets()
  return { [62] = { { name = "Guide M+", selections = { [100] = 1002 } } } }
end

describe("profile_store", function()
  local store
  before_each(function()
    store = wow_env.new({ presets = sample_presets() }).ns.profile_store
  end)

  it("legt fehlende Tabellen beim Init an", function()
    assert.same({ version = 1, profiles = {}, active = {} }, store.init(nil))
  end)

  it("behält vorhandene Daten beim Init", function()
    local db = store.init({ version = 1, profiles = { [62] = {} }, active = { [62] = "Alt" } })
    assert.equals("Alt", db.active[62])
    assert.equals(db, store.db)
  end)

  it("listet Presets vor eigenen Profilen, eigene alphabetisch", function()
    store.save(62, "Zeta", { [100] = 1001 })
    store.save(62, "Alpha", { [100] = 1001 })
    local names = {}
    for _, profile in ipairs(store.list(62)) do names[#names + 1] = profile.name end
    assert.same({ "Guide M+", "Alpha", "Zeta" }, names)
  end)

  it("speichert eine Kopie der Auswahl als eigenes Profil", function()
    local selections = { [100] = 1001 }
    assert.is_true(store.save(62, "Mein", selections))
    selections[100] = 1002
    local profile = store.get(62, "Mein")
    assert.equals(1001, profile.selections[100])
    assert.equals("user", profile.source)
  end)

  it("lehnt leere Namen und Preset-Namen ab", function()
    assert.same({ false, "empty_name" }, { store.save(62, "", {}) })
    assert.same({ false, "preset_name" }, { store.save(62, "Guide M+", {}) })
  end)

  it("löscht eigene Profile und setzt das aktive Profil zurück", function()
    store.save(62, "Mein", { [100] = 1001 })
    store.set_active(62, "Mein")
    assert.is_true(store.delete(62, "Mein"))
    assert.is_nil(store.get(62, "Mein"))
    assert.equals("Guide M+", store.active_name(62))
  end)

  it("schützt Presets und meldet unbekannte Profile beim Löschen", function()
    assert.same({ false, "preset_readonly" }, { store.delete(62, "Guide M+") })
    assert.same({ false, "not_found" }, { store.delete(62, "Gibt es nicht") })
  end)

  it("nimmt ohne gesetztes aktives Profil das erste Preset", function()
    assert.equals("Guide M+", store.get_active(62).name)
    assert.is_nil(store.get_active(63))
  end)

  it("setzt nur existierende Profile aktiv", function()
    assert.same({ false, "not_found" }, { store.set_active(62, "Fehlt") })
    store.save(62, "Mein", { [100] = 1001 })
    assert.is_true(store.set_active(62, "Mein"))
    assert.equals("Mein", store.get_active(62).name)
  end)
end)
