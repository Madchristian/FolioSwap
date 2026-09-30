local wow_env = require("spec.helpers.wow_env")
local frames = require("spec.helpers.frame_mock")

describe("WoW addon settings", function()
  it("registriert beim Login genau eine versteckte Kategorie ohne Foliantfenster", function()
    local ns = wow_env.new().ns
    frames.install()
    _G.RunesOfPowerMixin, _G.ExpansionLandingPage = nil, nil
    _G.FolioSwapDB = { skin = { theme = "flat", scale = 1.25 } }
    assert(loadfile("UI/FolioPanel.lua"))("FolioSwap", ns)
    assert(loadfile("Core/Bootstrap.lua"))("FolioSwap", ns)
    local bootstrap = frames.frames[#frames.frames]
    frames.fire(bootstrap, "OnEvent", "ADDON_LOADED", "Other")
    assert.equals(0, #frames.categories)
    frames.fire(bootstrap, "OnEvent", "ADDON_LOADED", "FolioSwap")
    assert.equals(1, #frames.categories)
    local category = frames.categories[1]
    local w = ns.skin_options.widgets
    assert.equals("FolioSwap", category.name)
    assert.equals(w.root, category.canvas)
    assert.is_false(w.root:IsShown())
    assert.is_nil(w.close)
    assert.is_nil(w.root.scripts.OnUpdate)
    assert.same({}, UISpecialFrames)
    ns.skin_options.register()
    assert.equals(1, #frames.categories)
    ns.slash_commands.handle("skin")
    assert.same({ category:GetID() }, frames.opened)
    assert.is_true(w.root:IsShown())
    assert.equals("> Flat", w.themes.flat.label:GetText())
    assert.equals(UIParent:GetEffectiveScale(), w.root:GetEffectiveScale())
    ns.skin.set("scale", 0.8)
    assert.equals(UIParent:GetEffectiveScale(), w.root:GetEffectiveScale())
    -- Direkter Aufruf aus Blizzards Kategorienliste aktualisiert die Werte ebenfalls.
    ns.profile_store.db.skin.opacity = 0.7
    frames.fire(w.root, "OnShow")
    assert.matches("70%%", w.opacity_label:GetText())
  end)
end)
