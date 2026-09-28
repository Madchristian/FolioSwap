local _, ns = ...
local L = ns.L

-- Leiste am Foliant-Fenster: Profil-Dropdown der aktuellen Spec plus Aktions-Buttons.
local folio_panel = { hooked = false }
ns.folio_panel = folio_panel

local SAVE_POPUP = "FOLIOSWAP_SAVE_PROFILE"
local BUTTON_WIDTH, BUTTON_HEIGHT, SPACING = 120, 22, 6

local panel, dropdown
local selected_name

local function selected_or_active()
  local spec_id = ns.player.current_spec_id()
  if not spec_id then return nil end
  if selected_name and ns.profile_store.get(spec_id, selected_name) then return selected_name end
  return ns.profile_store.active_name(spec_id)
end

local function refresh()
  if dropdown then dropdown:GenerateMenu() end
end
folio_panel.refresh = refresh

local function setup_menu(_, root)
  local spec_id = ns.player.current_spec_id()
  if not spec_id then return end
  local active_name = ns.profile_store.active_name(spec_id)
  for _, profile in ipairs(ns.profile_store.list(spec_id)) do
    root:CreateRadio(
      ns.reporter.profile_label(profile, active_name),
      function(name) return name == selected_or_active() end,
      function(name) selected_name = name end,
      profile.name
    )
  end
end

local function on_selected(action)
  return function()
    local name = selected_or_active()
    if name then action(name) end
    refresh()
  end
end

local function delete_selected(name)
  ns.actions.delete(name)
  selected_name = nil
end

local function save_from_popup(popup)
  local edit_box = popup.GetEditBox and popup:GetEditBox() or popup.editBox
  local name = edit_box:GetText():match("^%s*(.-)%s*$")
  ns.actions.save_current(name)
  selected_name = name
  refresh()
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

local function create_button(text, on_click, previous)
  local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  button:SetText(text)
  button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
  button:SetPoint("LEFT", previous, "RIGHT", SPACING, 0)
  button:SetScript("OnClick", on_click)
  return button
end

local function build(parent)
  panel = CreateFrame("Frame", nil, parent)
  panel:SetSize(4 * (BUTTON_WIDTH + SPACING) + 180, BUTTON_HEIGHT + 8)
  -- Die Rahmen-Textur des Foliant-Fensters reicht 13px unter den Fensterrand hinaus.
  panel:SetPoint("TOP", parent, "BOTTOM", 0, -16)

  dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
  dropdown:SetWidth(180)
  dropdown:SetPoint("LEFT", panel, "LEFT", 0, 0)
  dropdown:SetupMenu(setup_menu)

  local apply = create_button(L.panel_apply, on_selected(ns.actions.apply), dropdown)
  local save = create_button(L.panel_save, function() StaticPopup_Show(SAVE_POPUP) end, apply)
  local delete = create_button(L.panel_delete, on_selected(delete_selected), save)
  create_button(L.panel_activate, on_selected(ns.actions.set_active), delete)
end

local function attach(frame)
  if not panel then build(frame) end
  refresh()
end

-- Das Foliant-Fenster gehört zu einem nachladbaren Blizzard-Addon: bei jedem ADDON_LOADED erneut versuchen.
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
