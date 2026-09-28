local _, ns = ...
local L = ns.L

local reporter = { unavailable_reported = false }
ns.reporter = reporter

-- Austauschbar für Tests; im Spiel landet alles im Chat.
reporter.sink = print

function reporter.say(message)
  reporter.sink(L.prefix .. message)
end

function reporter.say_line(message)
  reporter.sink(message)
end

function reporter.report_unavailable()
  if reporter.unavailable_reported then return end
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
    parts[#parts + 1] = entry.node_id .. " (" .. L["reason_" .. entry.reason] .. ")"
  end
  return table.concat(parts, ", ")
end

-- verbose: manuelles Anwenden – auch "schon aktiv" und "busy" melden.
-- Ohne verbose (Automatik) bleibt "busy" still, weil der SwapController es erneut versucht.
function reporter.report_apply(profile, result, verbose)
  if result.reason == "unavailable" then return reporter.report_unavailable() end
  if result.reason == "busy" and not verbose then return end
  if #result.applied > 0 then
    reporter.say(L.applied:format(profile.name, #result.applied))
  elseif verbose and #result.skipped == 0 and not result.reason then
    reporter.say(L.unchanged:format(profile.name))
  end
  if #result.skipped > 0 then
    reporter.say(L.skipped:format(#result.skipped, profile.name, describe_skipped(result.skipped)))
  end
  -- commit_failed, busy, cannot_edit: der Grund ist zugleich der Text-Schlüssel.
  if result.reason then
    reporter.say(L[result.reason])
  end
end
