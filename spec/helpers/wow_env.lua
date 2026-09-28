-- Lädt das Addon in der Reihenfolge der .toc in eine frische Testumgebung.
local c_traits_mock = require("spec.helpers.c_traits_mock")

local wow_env = {}

local TOC_PATH = "FolioSwap.toc"
-- Reiner Frame-Code läuft nur im Spiel.
local SKIPPED = { ["UI/FolioPanel.lua"] = true, ["Core/Bootstrap.lua"] = true }

local function addon_files()
  local files = {}
  for line in io.lines(TOC_PATH) do
    local path = line:gsub("\\", "/"):match("^%s*(.-)%s*$")
    if path ~= "" and not path:find("^#") and not SKIPPED[path] then
      files[#files + 1] = path
    end
  end
  return files
end

-- opts: tree (Foliant-Mock), locale, spec_id, presets
function wow_env.new(opts)
  opts = opts or {}
  local env = { in_combat = false, spec_id = opts.spec_id or 62, messages = {} }

  env.traits = c_traits_mock.install(opts.tree or c_traits_mock.default_tree())
  C_Spell = { GetSpellName = function(spell_id) return "Spell " .. spell_id end }
  GetLocale = function() return opts.locale or "enUS" end
  InCombatLockdown = function() return env.in_combat end
  GetSpecialization = function() return env.spec_id and 1 or nil end
  GetSpecializationInfo = function() return env.spec_id end
  SlashCmdList = {}

  env.ns = {}
  for _, path in ipairs(addon_files()) do
    assert(loadfile(path))("FolioSwap", env.ns)
  end

  if env.ns.profile_store then env.ns.profile_store.init({}) end
  if env.ns.reporter then
    env.ns.reporter.sink = function(message) table.insert(env.messages, message) end
  end
  if opts.presets and env.ns.presets then env.ns.presets.data = opts.presets end
  return env
end

return wow_env
