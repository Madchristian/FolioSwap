local _, ns = ...
local L = ns.L

-- pending: im Kampf vorgemerkt; retry_after_commit: Spiel war beim Versuch noch mit Speichern beschäftigt.
local swap_controller = { pending = false, retry_after_commit = false }
ns.swap_controller = swap_controller

swap_controller.EVENTS = {
  "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED", "TRAIT_CONFIG_UPDATED",
}

-- Im Kampf lässt sich der Foliant nicht ändern: vormerken und bei Kampfende nachholen.
function swap_controller.request_apply()
  if not InCombatLockdown() then
    swap_controller.pending = false
    local result = ns.actions.apply_active()
    swap_controller.retry_after_commit = result ~= nil and result.reason == "busy"
    return
  end
  if not swap_controller.pending then
    ns.reporter.say(L.combat_pending)
  end
  swap_controller.pending = true
end

function swap_controller.on_event(event, ...)
  if event == "PLAYER_SPECIALIZATION_CHANGED" then
    local unit = ...
    if unit == "player" then swap_controller.request_apply() end
  elseif event == "PLAYER_ENTERING_WORLD" then
    local is_login, is_reload = ...
    if is_login or is_reload then swap_controller.request_apply() end
  elseif event == "PLAYER_REGEN_ENABLED" and swap_controller.pending then
    swap_controller.request_apply()
  elseif event == "TRAIT_CONFIG_UPDATED" and swap_controller.retry_after_commit then
    swap_controller.request_apply()
  end
end
