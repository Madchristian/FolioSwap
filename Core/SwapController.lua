local _, ns = ...
local L = ns.L

local RETRY_DELAY = 2
-- 1 Sofortversuch + MAX_RETRIES Wiederholungen
local MAX_RETRIES = 5
-- Für busy (Spiel speichert noch Talente) und unavailable (Foliant-Config beim Login evtl.
-- noch nicht geladen) gibt es kein zuverlässiges Event, das den richtigen Moment meldet –
-- deshalb per Timer wiederholen, statt auf ein Event zu warten.
local TRANSIENT = { busy = true, unavailable = true }

-- pending: im Kampf vorgemerkt. retries/retry_scheduled: laufender Timer-Retry bei busy/unavailable.
local swap_controller = { pending = false, retries = 0, retry_scheduled = false }
ns.swap_controller = swap_controller

swap_controller.EVENTS = {
  "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED",
}

-- Nach MAX_RETRIES gescheiterten Versuchen einmal melden und aufgeben, statt endlos zu pollen.
-- Rein internes Implementierungsdetail von request_apply, deshalb kein Tabellen-Eintrag.
local function schedule_retry(reason)
  if swap_controller.retries >= MAX_RETRIES then
    swap_controller.retries = 0
    if reason == "busy" then
      ns.reporter.say(L.busy)
    else
      ns.reporter.report_unavailable()
    end
    return
  end
  swap_controller.retries = swap_controller.retries + 1
  if swap_controller.retry_scheduled then return end
  swap_controller.retry_scheduled = true
  C_Timer.After(RETRY_DELAY, function()
    swap_controller.retry_scheduled = false
    swap_controller.request_apply()
  end)
end

-- Im Kampf lässt sich der Foliant nicht ändern: vormerken und bei Kampfende nachholen.
function swap_controller.request_apply()
  if not InCombatLockdown() then
    swap_controller.pending = false
    local result = ns.actions.apply_active()
    local reason = result and result.reason
    if TRANSIENT[reason] then
      schedule_retry(reason)
    else
      swap_controller.retries = 0
    end
    return
  end
  -- Nichts vormerken, wenn ohnehin kein Profil greift oder es schon passt.
  if not ns.actions.needs_apply() then return end
  if not swap_controller.pending then
    ns.reporter.say(L.combat_pending)
  end
  swap_controller.pending = true
end

-- Frisches Budget pro neuem Anlass: nur externe Auslöser (Spec-Wechsel, Login/Reload) setzen den
-- Zähler zurück, bevor request_apply läuft. Timer-Retries und PLAYER_REGEN_ENABLED (Fortsetzung
-- eines bereits laufenden Versuchs) behalten ihn bei.
function swap_controller.on_event(event, ...)
  if event == "PLAYER_SPECIALIZATION_CHANGED" then
    local unit = ...
    if unit == "player" then
      swap_controller.retries = 0
      swap_controller.request_apply()
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    local is_login, is_reload = ...
    if is_login or is_reload then
      swap_controller.retries = 0
      swap_controller.request_apply()
    end
  elseif event == "PLAYER_REGEN_ENABLED" and swap_controller.pending then
    swap_controller.request_apply()
  end
end
