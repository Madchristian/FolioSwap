local addon_name, ns = ...

local frame = CreateFrame("Frame")

local function on_addon_loaded(loaded_name)
  if loaded_name == addon_name then
    FolioSwapDB = ns.profile_store.init(FolioSwapDB)
    for _, event in ipairs(ns.swap_controller.EVENTS) do
      frame:RegisterEvent(event)
    end
  end
  ns.folio_panel.try_attach()
end

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    on_addon_loaded(...)
  else
    ns.swap_controller.on_event(event, ...)
  end
end)
frame:RegisterEvent("ADDON_LOADED")
