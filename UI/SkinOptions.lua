local _, ns = ...
local ui, L = ns.flat_ui, ns.L
local options = { widgets = { accents = {} } }
ns.skin_options = options
local w = options.widgets

local function refresh()
  if w.root then
    local settings = ns.skin.get()
    w.opacity_label:SetText(L.skin_opacity .. ": " .. math.floor(settings.opacity * 100 + 0.5) .. "%")
    w.scale_label:SetText(L.skin_scale .. ": " .. math.floor(settings.scale * 100 + 0.5) .. "%")
    for key, button in pairs(w.accents) do
      button.selected = key == settings.accent
      button.label:SetText((button.selected and "> " or "") .. L["skin_" .. key])
    end
    w.opacity_minus:SetEnabled(settings.opacity > 0.65)
    w.opacity_plus:SetEnabled(settings.opacity < 1)
    w.scale_minus:SetEnabled(settings.scale > 0.8)
    w.scale_plus:SetEnabled(settings.scale < 1.25)
  end
  ui.refresh()
end
ns.skin.refresh = refresh

local function step(key, delta)
  return function() ns.skin.set(key, math.floor((ns.skin.get()[key] + delta) * 100 + 0.5) / 100) end
end

local function build()
  w.root = ui.surface(UIParent, "FolioSwapSkinOptions", 360, 244, true)
  w.root:SetPoint("CENTER")
  w.root:SetClampedToScreen(true)
  w.root.layout = function() ui.keep_on_screen(w.root) end
  w.root:SetScript("OnUpdate", w.root.layout)
  w.root:SetFrameStrata("DIALOG")
  table.insert(UISpecialFrames, "FolioSwapSkinOptions")
  local title = ui.label(w.root, "FolioSwap - " .. L.panel_skin, 280)
  title:SetPoint("TOPLEFT", 16, -16)
  w.close = ui.button(w.root, "X", 28, function() w.root:Hide() end)
  w.close:SetPoint("TOPRIGHT", -8, -8)
  local accent = ui.label(w.root, L.skin_accent, 328)
  accent:SetPoint("TOPLEFT", 16, -48)
  for i, key in ipairs({ "teal", "blue", "violet", "amber" }) do
    local accent_key = key
    local b = ui.button(w.root, L["skin_" .. key], 78, function() ns.skin.set("accent", accent_key) end)
    b:SetPoint("TOPLEFT", 16 + (i - 1) * 83, -68)
    w.accents[key] = b
  end
  for i, key in ipairs({ "opacity", "scale" }) do
    local y = -110 - (i - 1) * 38
    w[key .. "_label"] = ui.label(w.root, "", 232)
    w[key .. "_label"]:SetPoint("TOPLEFT", 16, y - 6)
    w[key .. "_minus"] = ui.button(w.root, "-", 32, step(key, -0.05))
    w[key .. "_minus"]:SetPoint("TOPLEFT", 266, y)
    w[key .. "_plus"] = ui.button(w.root, "+", 32, step(key, 0.05))
    w[key .. "_plus"]:SetPoint("TOPLEFT", 306, y)
  end
  w.reset = ui.button(w.root, L.skin_reset, 328, ns.skin.reset)
  w.reset:SetPoint("BOTTOMLEFT", 16, 30)
  local hint = ui.label(w.root, L.skin_account, 328)
  hint:SetPoint("BOTTOMLEFT", 16, 10)
end

function options.show()
  local panel = ns.folio_panel and ns.folio_panel.widgets
  if panel and panel.menu then panel.menu:Hide() end
  if not w.root then build() end
  -- Gleiche Strata, aber oberhalb des Folianten; bei jedem Öffnen neu bestimmen.
  if panel and panel.panel then
    w.root:SetFrameStrata(panel.panel:GetFrameStrata())
    w.root:SetFrameLevel(panel.panel:GetFrameLevel() + 10)
  end
  refresh()
  w.root:Show()
end
