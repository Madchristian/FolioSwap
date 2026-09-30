local wow_env = require("spec.helpers.wow_env")

describe("account skin", function()
  it("migriert bestehende Werte additiv und persistiert beide Stile ohne Profilreset", function()
    local ns = wow_env.new().ns
    local db = ns.profile_store.init({ skin = { accent = "amber", opacity = 0.94, scale = 1.15 } })
    ns.profile_store.save(62, "Keep", { [1] = 2 })
    ns.profile_store.set_active(62, "Keep")
    local profiles, active = db.profiles, db.active
    assert.same({ theme = "foliant", accent = "amber", opacity = 0.94, scale = 1.15 }, db.skin)
    for _, theme in ipairs({ "flat", "foliant" }) do
      ns.skin.set("theme", theme)
      ns.profile_store.init(db)
      assert.equals(theme, db.skin.theme)
      assert.equals("amber", db.skin.accent)
      assert.equals(0.94, db.skin.opacity)
      assert.equals(1.15, db.skin.scale)
    end
    for _, bad in ipairs({ "Flat", "unknown", false, 123, {} }) do
      ns.skin.set("theme", bad)
      assert.equals("foliant", db.skin.theme)
      assert.equals("amber", db.skin.accent)
    end
    ns.skin.reset()
    assert.same({ theme = "foliant", accent = "teal", opacity = 0.98, scale = 1 }, db.skin)
    assert.equals(profiles, db.profiles)
    assert.equals(active, db.active)
    assert.equals("Keep", ns.profile_store.active_name(62))
    assert.same({ [1] = 2 }, ns.profile_store.get(62, "Keep").selections)
    ns.profile_store.db = nil
    assert.same(ns.skin.normalize(), ns.skin.get())
  end)

  it("normalisiert nur Skin-Daten und persistiert Änderungen ohne Profile anzutasten", function()
    local ns = wow_env.new().ns
    assert.is_table(ns.skin)
    local db = ns.profile_store.init({ skin = { accent = "invalid", opacity = 0/0, scale = math.huge } })
    assert.same({ theme = "foliant", accent = "teal", opacity = 0.98, scale = 1 }, db.skin)
    ns.profile_store.save(62, "Keep", { [1] = 2 })
    local profiles = db.profiles
    ns.skin.set("accent", "violet")
    ns.skin.set("opacity", 0.8)
    ns.skin.set("scale", 1.2)
    ns.profile_store.init(db)
    assert.same({ theme = "foliant", accent = "violet", opacity = 0.8, scale = 1.2 }, db.skin)
    assert.equals(profiles, db.profiles)
    ns.skin.set("scale", 99)
    ns.skin.set("opacity", -10)
    assert.equals(1.25, db.skin.scale)
    assert.equals(0.65, db.skin.opacity)
    ns.skin.set("profiles", {})
    assert.equals(profiles, db.profiles)
    ns.skin.reset()
    assert.same({ theme = "foliant", accent = "teal", opacity = 0.98, scale = 1 }, db.skin)
    assert.same({ [1] = 2 }, ns.profile_store.get(62, "Keep").selections)
    for _, bad in ipairs({ false, "bad", 4, {} }) do
      ns.profile_store.init({ skin = bad })
      assert.same({ theme = "foliant", accent = "teal", opacity = 0.98, scale = 1 }, ns.profile_store.db.skin)
    end
  end)
end)
