local wow_env = require("spec.helpers.wow_env")
local frames = require("spec.helpers.frame_mock")
local function setup()
  local env = wow_env.new()
  frames.install()
  assert(loadfile("UI/FolioPanel.lua"))("FolioSwap", env.ns)
  env.ns.folio_panel.try_attach()
  return env, env.ns.folio_panel
end

describe("flat folio panel", function()
  it("lädt TOC und gespeicherten Skin beim echten Bootstrap erneut", function()
    local env = wow_env.new()
    frames.install()
    local db = env.ns.profile_store.db
    env.ns.skin.set("accent", "amber")
    env.ns.skin.set("scale", 0.8)
    env.ns.profile_store.save(62, "Retained", { [100] = 1002 })
    _G.FolioSwapDB = db
    local ns = {}
    for line in io.lines("FolioSwap.toc") do
      local path = line:gsub("\\", "/"):match("^%s*(.-)%s*$")
      if path:match("%.lua$") then assert(loadfile(path))("FolioSwap", ns) end
    end
    local bootstrap = frames.frames[#frames.frames]
    frames.fire(bootstrap, "OnEvent", "ADDON_LOADED", "FolioSwap")
    assert.equals(db, ns.profile_store.db)
    assert.equals("amber", ns.skin.get().accent)
    assert.equals(0.8, ns.folio_panel.widgets.panel.scale)
    assert.same({ [100] = 1002 }, ns.profile_store.get(62, "Retained").selections)
    ns.skin_options.show()
    local count = #frames.frames
    local parent = ExpansionLandingPage.Overlay.MidnightLandingOverlay.RunesOfPowerFrame
    for _ = 1, 10 do frames.fire(parent, "OnShow") end
    assert.equals(count, #frames.frames)
    assert.same({ "FolioSwapProfileMenu", "FolioSwapSkinOptions" }, UISpecialFrames)
  end)

  it("behält den vorhandenen automatischen Aktionspfad für vier echte Spec-IDs", function()
    local env = setup()
    local ns = env.ns
    local entries = { [102] = 4002, [103] = 4003, [104] = 4004, [105] = 4001 }
    for id, entry in pairs(entries) do
      ns.profile_store.save(id, "Same name", { [400] = entry })
      ns.profile_store.set_active(id, "Same name")
    end
    for _, id in ipairs({ 102, 103, 104, 105 }) do
      env.spec_id = id
      ns.swap_controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "player")
      assert.same({ 400, entries[id] }, env.traits.set_calls[#env.traits.set_calls])
    end
    assert.equals(4, env.traits.commits)
  end)

  it("keeps selection and paging inside a 768-high viewport at every scale", function()
    for _, root_scale in ipairs({ 0.64, 1 }) do
      for _, scale in ipairs({ 0.8, 1, 1.25 }) do
        local env = wow_env.new()
        frames.install()
        UIParent:SetScale(root_scale)
        local parent = ExpansionLandingPage.Overlay.MidnightLandingOverlay.RunesOfPowerFrame
        parent:SetSize(600, 670)
        parent:SetPoint("TOP", UIParent, "TOP", 0, -10)
        env.ns.skin.set("scale", scale)
        assert(loadfile("UI/FolioPanel.lua"))("FolioSwap", env.ns)
        env.ns.folio_panel.try_attach()
        local w = env.ns.folio_panel.widgets
        local function visible(f)
          local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
          assert.is_true(f:GetLeft() * s >= -0.001, "left edge outside viewport")
          assert.is_true(f:GetBottom() * s >= -0.001, "bottom edge outside viewport")
          assert.is_true(f:GetRight() * s <= UIParent:GetWidth() + 0.001, "right edge outside viewport")
          assert.is_true(f:GetTop() * s <= UIParent:GetHeight() + 0.001, "top edge outside viewport")
        end
        for i = 1, 19 do env.ns.actions.save_current(string.format("Profile %02d", i)) end
        visible(w.panel)
        visible(w.selector)
        frames.fire(w.selector, "OnClick")
        visible(w.menu)
        assert.is_true(w.menu:GetBottom() >= w.selector:GetTop(), "menu opens upward near bottom")
        for _, row in ipairs(w.rows) do visible(row) end
        visible(w.previous)
        visible(w.next)
        assert.is_true(w.next:IsEnabled())
        frames.fire(w.next, "OnClick")
        visible(w.rows[1])
        frames.fire(w.rows[1], "OnClick")
        assert.matches("Profile 07", w.selector.label:GetText())
        frames.fire(w.selector, "OnClick")
        frames.fire(w.previous, "OnClick")
        assert.equals("Profile 01", w.rows[1].profile_name)
        -- Follow a moved folio, including horizontal overflow, without allocating frames.
        parent:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -200, -10)
        frames.fire(w.panel, "OnUpdate")
        visible(w.panel)
        visible(w.menu)
        env.ns.skin_options.show()
        local options = env.ns.skin_options.widgets
        visible(options.root)
        visible(options.close)
        visible(options.scale_plus)
        visible(options.reset)
        UIParent:SetSize(1366, 1600)
        parent:SetPoint("TOP", UIParent, "TOP", 0, -10)
        frames.fire(w.selector, "OnClick")
        visible(w.menu)
        assert.is_true(w.menu:GetTop() <= w.selector:GetBottom(), "menu opens downward when space permits")
      end
    end
  end)

  it("bounds settings after viewport changes and tolerates pending layout", function()
    local env, panel = setup()
    local parent = panel.widgets.panel:GetParent()
    parent.unlaid = true
    panel.refresh()
    frames.fire(panel.widgets.panel, "OnUpdate")
    parent.unlaid = false
    parent:SetSize(600, 670)
    parent:SetPoint("TOP", UIParent, "TOP", 0, -10)
    frames.fire(panel.widgets.panel, "OnUpdate")
    assert.is_true(panel.widgets.panel:GetBottom() >= 0)
    env.ns.skin_options.show()
    local root = env.ns.skin_options.widgets.root
    root:ClearAllPoints()
    root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1300, -100)
    for _, scale in ipairs({ 0.8, 1.25 }) do
      env.ns.skin.set("scale", scale)
      frames.fire(root, "OnUpdate")
      assert.is_true(root:GetBottom() >= 0)
      assert.is_true(root:GetRight() * root:GetEffectiveScale() <= UIParent:GetWidth() + 0.001)
      assert.is_true(root:GetTop() * root:GetEffectiveScale() <= UIParent:GetHeight() + 0.001)
    end
  end)

  it("hält Geometrie und Frames bei beiden Sprachen und Skalengrenzen stabil", function()
    for _, locale in ipairs({ "enUS", "deDE" }) do
      local env = wow_env.new({ locale = locale })
      frames.install()
      assert(loadfile("UI/FolioPanel.lua"))("FolioSwap", env.ns)
      env.ns.folio_panel.try_attach()
      env.ns.skin_options.show()
      local w = env.ns.folio_panel.widgets
      local count = #frames.frames
      for _, scale in ipairs({ 0.8, 1.25 }) do
        env.ns.skin.set("scale", scale)
        assert.equals(scale, w.panel.scale)
        for _, b in ipairs({ w.apply, w.save, w.delete, w.activate }) do
          assert.is_true(b.point[2] + b.width <= w.panel.width - 12)
        end
        env.ns.folio_panel.refresh()
        env.ns.skin_options.show()
        assert.equals(count, #frames.frames)
      end
      for _, f in ipairs(frames.frames) do assert.is_nil(f.template) end
    end
  end)

  it("trennt alle vier Druiden-Specs und verwirft alte Auswahl beim echten Spec-Event", function()
    local env, panel = setup()
    local ns, w = env.ns, panel.widgets
    assert.is_table(w.spec_label)
    local specs = { 102, 103, 104, 105 }
    _G.GetSpecializationInfo = function()
      return env.spec_id, "Spec " .. env.spec_id, "", 1000 + env.spec_id
    end
    for _, id in ipairs(specs) do
      ns.profile_store.save(id, "Shared", { [100] = id })
      ns.profile_store.save(id, "Active " .. id, { [100] = id })
      ns.profile_store.set_active(id, "Active " .. id)
    end
    assert(loadfile("Core/Bootstrap.lua"))("FolioSwap", ns)
    local event_frame = frames.frames[#frames.frames]
    for _, id in ipairs(specs) do
      env.spec_id = id
      frames.fire(event_frame, "OnEvent", "PLAYER_SPECIALIZATION_CHANGED", "player")
      assert.matches("Spec " .. id, w.spec_label:GetText())
      assert.equals(1000 + id, w.spec_icon.texture)
      assert.matches("Active " .. id, w.selector.label:GetText())
      assert.matches("Active " .. id, w.active_label:GetText())
      frames.fire(w.selector, "OnClick")
      frames.fire(w.rows[2], "OnClick")
      assert.matches("Shared", w.selector.label:GetText())
      assert.equals(id, ns.profile_store.get(id, "Shared").selections[100])
    end
    for _, id in ipairs(specs) do assert.equals("Active " .. id, ns.profile_store.active_name(id)) end
    frames.fire(w.activate, "OnClick")
    assert.equals("Shared", ns.profile_store.active_name(105))
    assert.equals("Active 104", ns.profile_store.active_name(104))
    env.spec_id = nil
    panel.refresh()
    assert.equals(ns.L.no_spec, w.spec_label:GetText())
    assert.is_false(w.apply:IsEnabled())
    assert.is_false(w.save:IsEnabled())
  end)

  it("öffnet Skin über Panel und Slash, aktualisiert sofort und verwendet Frames erneut", function()
    local env, panel = setup()
    local ns = env.ns
    assert.is_table(panel.widgets.skin)
    ns.actions.save_current("Menu entry")
    frames.fire(panel.widgets.selector, "OnClick")
    assert.is_true(panel.widgets.menu:IsShown())
    frames.fire(panel.widgets.skin, "OnClick")
    assert.is_false(panel.widgets.menu:IsShown())
    local w = ns.skin_options.widgets
    assert.is_true(w.root:IsShown())
    frames.fire(w.accents.violet, "OnClick")
    assert.equals("violet", ns.profile_store.db.skin.accent)
    assert.is_true(w.accents.violet.selected)
    frames.fire(w.opacity_minus, "OnClick")
    assert.is_true(ns.skin.get().opacity < 0.94)
    assert.equals(ns.skin.get().opacity, panel.widgets.panel.surface.color[4])
    frames.fire(w.scale_plus, "OnClick")
    assert.equals(1.05, panel.widgets.panel.scale)
    assert.equals(1.05, w.root.scale)
    local count = #frames.frames
    frames.fire(w.close, "OnClick")
    assert.is_false(w.root:IsShown())
    for _ = 1, 10 do ns.slash_commands.handle("skin") end
    assert.is_true(w.root:IsShown())
    assert.equals(count, #frames.frames)
    frames.fire(w.reset, "OnClick")
    assert.same({ accent = "teal", opacity = 0.94, scale = 1 }, ns.skin.get())
  end)

  it("öffnet Skin über dem Folianten auch nach Änderung seiner Fensterebene", function()
    local env, panel = setup()
    local host = panel.widgets.panel
    for _, strata in ipairs({ "DIALOG", "FULLSCREEN_DIALOG" }) do
      host:GetParent():SetFrameStrata(strata)
      host:SetFrameLevel(200)
      frames.fire(panel.widgets.skin, "OnClick")
      local root = env.ns.skin_options.widgets.root
      assert.equals(host:GetFrameStrata(), root:GetFrameStrata())
      assert.is_true(root:GetFrameLevel() > host:GetFrameLevel())
      frames.fire(env.ns.skin_options.widgets.close, "OnClick")
    end
  end)

  it("öffnet Skin ohne geladenes Blizzard-Foliantfenster", function()
    local ns = wow_env.new().ns
    frames.install()
    ns.slash_commands.handle("skin")
    assert.is_table(ns.skin_options)
    assert.is_true(ns.skin_options.widgets.root:IsShown())
  end)

  it("ersetzt Buttons und Auswahl vollständig und führt bestehende Aktionen aus", function()
    local env, panel = setup()
    for _, frame in ipairs(frames.frames) do assert.is_nil(frame.template) end
    local w, ns = panel.widgets, env.ns
    assert.is_false(w.apply:IsEnabled())
    assert.is_false(w.delete:IsEnabled())
    ns.actions.save_current("Alpha")
    ns.actions.save_current("Beta")
    assert.equals(ns.L.panel_choose, w.selector.label:GetText())
    assert.equals("v", w.selector.arrow:GetText())
    frames.fire(w.selector, "OnClick")
    assert.is_true(w.menu:IsShown())
    frames.fire(w.rows[2], "OnClick")
    assert.is_false(w.menu:IsShown())
    assert.matches("Beta", w.selector.label:GetText())
    assert.is_true(w.apply:IsEnabled())
    frames.fire(w.activate, "OnClick")
    assert.equals("Beta", ns.profile_store.active_name(62))
    -- A distinct saved selection must reach C_Traits, not merely leave an old chat message.
    ns.profile_store.save(62, "Beta", { [100] = 1002 })
    local calls, commits, messages = #env.traits.set_calls, env.traits.commits, #env.messages
    frames.fire(w.apply, "OnClick")
    assert.equals(calls + 1, #env.traits.set_calls)
    assert.same({ 100, 1002 }, env.traits.set_calls[#env.traits.set_calls])
    assert.equals(commits + 1, env.traits.commits)
    assert.equals(1002, C_Traits.GetNodeInfo(7, 100).activeEntry.entryID)
    assert.equals(messages + 1, #env.messages)
    assert.matches("Beta", env.messages[#env.messages])
    frames.fire(w.delete, "OnClick")
    assert.is_nil(ns.profile_store.get(62, "Beta"))
    assert.is_false(w.apply:IsEnabled())
    frames.fire(w.save, "OnClick")
    assert.equals(ns.L.save_prompt, frames.popup.text)
    frames.popup.OnAccept({ editBox = { GetText = function() return "Saved" end } })
    assert.is_table(ns.profile_store.get(62, "Saved"))
    assert.matches("Saved", w.selector.label:GetText())
  end)

  it("begrenzt Auswahl auf sechs wiederverwendete Zeilen mit Seitenwechsel", function()
    local env, panel = setup()
    local ns, w = env.ns, panel.widgets
    assert.is_table(w)
    for i = 1, 19 do ns.actions.save_current(string.format("Profile %02d", i)) end
    frames.fire(w.selector, "OnClick")
    local count = #frames.frames
    frames.fire(w.next, "OnClick")
    frames.fire(w.rows[1], "OnClick")
    assert.matches("Profile 07", w.selector.label:GetText())
    for _ = 1, 20 do
      frames.fire(w.selector, "OnClick")
      panel.refresh()
    end
    assert.equals(count, #frames.frames)
    frames.fire(w.next, "OnClick")
    frames.fire(w.next, "OnClick")
    assert.is_false(w.next:IsEnabled())
    for i = 1, 19 do ns.actions.delete(string.format("Profile %02d", i)) end
    assert.is_false(w.selector:IsEnabled())
    assert.is_false(w.rows[1]:IsShown())
    ns.actions.save_current("Only")
    assert.equals("Only", w.rows[1].profile_name)
    ns.presets.data[62] = { { name = "Guide", selections = {} } }
    panel.refresh()
    frames.fire(w.rows[1], "OnClick")
    assert.is_false(w.delete:IsEnabled())
  end)
end)
