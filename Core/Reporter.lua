local _, ns = ...
local L = ns.L

-- reported_skips: [source|name|sortierte "node_id:entry_id:reason"-Liste] = true.
-- Verhindert, dass die Automatik dieselbe übersprungene Kombination jede Sitzung erneut meldet.
local reporter = { unavailable_reported = false, reported_skips = {} }
ns.reporter = reporter

-- Austauschbar für Tests; im Spiel landet alles im Chat.
reporter.sink = print

function reporter.say(message)
  reporter.sink(L.prefix .. message)
end

function reporter.say_line(message)
  reporter.sink(message)
end

-- force: Drosselung umgehen (manuelle Befehle sollen den Hinweis immer zeigen;
-- die Automatik bleibt nach der ersten Meldung pro Sitzung still).
function reporter.report_unavailable(force)
  if reporter.unavailable_reported and not force then return end
  reporter.unavailable_reported = true
  reporter.say(L.unavailable)
end

function reporter.profile_label(profile, active_name)
  local label = profile.name
  if profile.source == "preset" then label = label .. L.preset_marker end
  if profile.name == active_name then label = label .. L.active_marker end
  return label
end

local function describe_skipped(skipped)
  local parts = {}
  for _, entry in ipairs(skipped) do
    parts[#parts + 1] = (entry.name or entry.node_id) .. " (" .. L["reason_" .. entry.reason] .. ")"
  end
  return table.concat(parts, ", ")
end

-- Kombination aus Profil (Quelle + Name - report_apply kennt keine spec_id) und den
-- übersprungenen node_id/entry_id/reason-Tripeln, unabhängig von der Reihenfolge - identifiziert,
-- ob die Automatik genau dieses Ergebnis schon gemeldet hat. Die gewünschte entry_id gehört mit in
-- den Schlüssel, damit zwei gleich benannte Profile mit unterschiedlicher Rune nicht kollidieren.
local function skip_key(profile, skipped)
  local parts = {}
  for _, entry in ipairs(skipped) do
    parts[#parts + 1] = entry.node_id .. ":" .. tostring(entry.entry_id) .. ":" .. entry.reason
  end
  table.sort(parts)
  return tostring(profile.source) .. "|" .. profile.name .. "|" .. table.concat(parts, ",")
end

-- verbose: manuelles Anwenden – auch "schon aktiv", "busy" und "unavailable" melden.
-- Ohne verbose (Automatik) bleiben "busy" und "unavailable" komplett still: der SwapController
-- meldet sie erst selbst, wenn alle Wiederholungsversuche per Timer gescheitert sind.
function reporter.report_apply(profile, result, verbose)
  if result.reason == "pending" then return end
  if not verbose and (result.reason == "busy" or result.reason == "unavailable") then return end
  if result.reason == "unavailable" then return reporter.report_unavailable(true) end
  if #result.applied > 0 then
    reporter.say(L.applied:format(profile.name, #result.applied))
  elseif verbose and #result.skipped == 0 and not result.reason then
    reporter.say(L.unchanged:format(profile.name))
  end
  if #result.skipped > 0 then
    local key = skip_key(profile, result.skipped)
    if verbose or not reporter.reported_skips[key] then
      reporter.reported_skips[key] = true
      reporter.say(L.skipped:format(#result.skipped, profile.name, describe_skipped(result.skipped)))
    end
  end
  -- commit_failed, commit_timeout, busy, cannot_edit: Grund ist zugleich der Text-Schlüssel.
  if result.reason then
    reporter.say(L[result.reason])
  end
end
