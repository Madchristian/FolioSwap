local _, ns = ...
local L, ui = ns.L, ns.flat_ui
local folio_panel = { hooked = false }
ns.folio_panel = folio_panel
local SAVE_POPUP = "FOLIOSWAP_SAVE_PROFILE"
local panel, selected_name, selected_spec
local page, PAGE_SIZE = 1, 6
local w = { rows = {} }
folio_panel.widgets = w

local function selected_or_active()
  local spec_id = ns.player.current_spec_id()
  if not spec_id then return nil end
  if selected_name and ns.profile_store.get(spec_id, selected_name) then return selected_name end
  return ns.profile_store.active_name(spec_id)
end

local function refresh()
  if not panel then return end
  local spec_id = ns.player.current_spec_id()
  if spec_id ~= selected_spec then
    selected_spec, selected_name, page = spec_id, nil, 1
    w.menu:Hide()
  end
  local index = GetSpecialization()
  local spec_name, icon
  if index then
    local _, name, _, texture = GetSpecializationInfo(index)
    spec_name, icon = name, texture
  end
  w.spec_label:SetText(spec_id and ("FolioSwap - " .. (spec_name or tostring(spec_id))) or L.no_spec)
  w.spec_icon:SetTexture(icon)
  local profiles = spec_id and ns.profile_store.list(spec_id) or {}
  local active = spec_id and ns.profile_store.active_name(spec_id)
  w.active_label:SetText(L.panel_automatic .. ": " .. (active or L.panel_none))
  w.active_label.assigned = active ~= nil
  local name = selected_or_active()
  local profile = name and ns.profile_store.get(spec_id, name)
  local placeholder = #profiles > 0 and L.panel_choose or L.no_profiles
  w.selector.label:SetText(profile and ns.reporter.profile_label(profile, active) or placeholder)
  w.selector.assigned = profile ~= nil and name == active
  w.selector:SetEnabled(#profiles > 0)
  w.apply:SetEnabled(profile ~= nil)
  w.activate:SetEnabled(profile ~= nil)
  w.delete:SetEnabled(profile ~= nil and profile.source == "user")
  w.save:SetEnabled(spec_id ~= nil)
  local pages = math.max(1, math.ceil(#profiles / PAGE_SIZE))
  page = math.min(page, pages)
  for i, row in ipairs(w.rows) do
    local entry = profiles[(page - 1) * PAGE_SIZE + i]
    row.profile_name = entry and entry.name
    if entry then
      row.label:SetText((entry.name == name and "> " or "") .. ns.reporter.profile_label(entry, active))
      row.selected = entry.name == name
      row:Show()
    else
      row.selected = false
      row:Hide()
    end
  end
  w.previous:SetEnabled(page > 1)
  w.next:SetEnabled(page < pages)
  w.page_label:SetText(page .. " / " .. pages)
  ui.refresh()
end
folio_panel.refresh = refresh

local function on_selected(action)
  return function()
    local name = selected_or_active()
    if name then action(name) end
  end
end

local function delete_selected(name)
  if ns.actions.delete(name) then selected_name = nil; refresh() end
end

local function save_from_popup(popup)
  local edit_box = popup.GetEditBox and popup:GetEditBox() or popup.editBox
  local name = ns.util.trim(edit_box:GetText())
  if ns.actions.save_current(name) then
    -- save_current hat schon aktualisiert, aber noch mit dem alten selected_name;
    -- ohne dieses zweite refresh() zeigt das Dropdown das vorher gewählte Profil.
    selected_name = name
    refresh()
  end
end

StaticPopupDialogs[SAVE_POPUP] = {
  text = L.save_prompt,
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = true,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  OnAccept = save_from_popup,
  EditBoxOnEnterPressed = function(edit_box)
    local popup = edit_box:GetParent()
    save_from_popup(popup)
    popup:Hide()
  end,
  -- Ohne das schließt Escape den Dialog nicht, solange die EditBox den Fokus hat.
  EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
}

local function build(parent)
  panel = ui.surface(parent, nil, 520, 132, true)
  w.panel = panel
  w.spec_icon = panel:CreateTexture(nil, "ARTWORK")
  w.spec_icon:SetSize(18, 18)
  w.spec_icon:SetPoint("TOPLEFT", 12, -10)
  w.spec_label = ui.label(panel, "FolioSwap", 394)
  w.spec_label:SetPoint("TOPLEFT", 38, -12)
  w.active_label = ui.label(panel, "", 496)
  w.active_label:SetPoint("BOTTOMLEFT", 12, 12)
  w.skin = ui.button(panel, L.panel_skin, 64, ns.skin_options.show)
  w.skin:SetPoint("TOPRIGHT", -12, -6)
  w.selector = ui.button(panel, L.no_profiles, 496, function()
    if w.menu:IsShown() then w.menu:Hide() else refresh(); w.menu:Show() end
  end)
  w.selector:SetPoint("TOPLEFT", 12, -36)
  w.selector.label:SetJustifyH("LEFT")
  w.selector.label:SetWidth(456)
  w.selector.arrow = ui.label(w.selector, "v", 12)
  w.selector.arrow:SetPoint("RIGHT", -8, 0)
  w.apply = ui.button(panel, L.panel_apply, 84, on_selected(ns.actions.apply))
  w.apply.primary = true
  w.save = ui.button(panel, L.panel_save, 110, function() StaticPopup_Show(SAVE_POPUP) end)
  w.delete = ui.button(panel, L.panel_delete, 74, on_selected(delete_selected))
  w.activate = ui.button(panel, L.panel_activate, 210, on_selected(ns.actions.set_active))
  local offsets = { 12, 102, 218, 298 }
  for i, b in ipairs({ w.apply, w.save, w.delete, w.activate }) do
    b:SetPoint("TOPLEFT", offsets[i], -72)
  end
  w.menu = ui.surface(panel, "FolioSwapProfileMenu", 496, 220)
  w.menu:SetPoint("TOPLEFT", w.selector, "BOTTOMLEFT", 0, -4)
  w.menu:SetFrameStrata("DIALOG")
  table.insert(UISpecialFrames, "FolioSwapProfileMenu")
  for i = 1, PAGE_SIZE do
    local row = ui.button(w.menu, "", 480, function(self)
      selected_name = self.profile_name
      w.menu:Hide()
      refresh()
    end)
    row:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 28)
    row.label:SetJustifyH("LEFT")
    w.rows[i] = row
  end
  w.previous = ui.button(w.menu, "<", 42, function() page = page - 1; refresh() end)
  w.previous:SetPoint("BOTTOMLEFT", 8, 8)
  w.next = ui.button(w.menu, ">", 42, function() page = page + 1; refresh() end)
  w.next:SetPoint("BOTTOMRIGHT", -8, 8)
  w.page_label = ui.label(w.menu, "", 100)
  w.page_label:SetPoint("BOTTOM", 0, 14)
  w.page_label:SetJustifyH("CENTER")
  w.menu:Hide()
  panel:SetScript("OnHide", function() w.menu:Hide() end)
  panel:SetClampedToScreen(true)
  panel.layout = function()
    panel:ClearAllPoints()
    local gap = ns.skin.get().theme == "foliant" and 4 or 16
    panel:SetPoint("TOP", parent, "BOTTOM", 0, -gap)
    ui.keep_on_screen(panel)
    w.menu:ClearAllPoints()
    w.menu:SetPoint("TOPLEFT", w.selector, "BOTTOMLEFT", 0, -4)
    local bottom = w.menu:GetBottom()
    if bottom and bottom < 0 then
      w.menu:ClearAllPoints()
      w.menu:SetPoint("BOTTOMLEFT", w.selector, "TOPLEFT", 0, 4)
    end
    ui.keep_on_screen(w.menu)
  end
  panel:SetScript("OnUpdate", panel.layout)
end

local function attach(frame)
  if not panel then build(frame) end
  refresh()
end

function folio_panel.try_attach()
  if folio_panel.hooked or not RunesOfPowerMixin then return end
  folio_panel.hooked = true
  hooksecurefunc(RunesOfPowerMixin, "OnShow", attach)
  local overlay = ExpansionLandingPage and ExpansionLandingPage.Overlay
    and ExpansionLandingPage.Overlay.MidnightLandingOverlay
  local frame = overlay and overlay.RunesOfPowerFrame
  if frame then
    frame:HookScript("OnShow", attach)
    if frame:IsShown() then attach(frame) end
  end
end
