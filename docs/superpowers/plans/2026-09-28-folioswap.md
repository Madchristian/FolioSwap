# FolioSwap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** WoW-Addon (Retail 12.1.0), das die Runen des Omniumfolianten beim Spec-Wechsel automatisch auf ein gespeichertes Profil oder ein Guide-Preset umstellt.

**Architecture:** Ein Namespace-Addon (`local _, ns = ...`) mit strikt getrennten Modulen: `folio_api` kapselt als einziges Modul `C_Traits` (System 48 / Tree 1186), `profile_store` verwaltet `FolioSwapDB`, `presets` liefert die Guide-Daten, `actions` bündelt die Anwendungsfälle für Slash-Befehle, Panel und Automatik, `swap_controller` reagiert auf Events. Frame-Code (Panel, Bootstrap) ist dünn und wird nur ingame geprüft; alles andere läuft unter busted gegen eine gemockte API.

**Tech Stack:** Lua 5.1 (WoW), busted + luacheck (lokal über hererocks, in CI über leafo/gh-actions-lua), BigWigs-Packager für GitHub Releases und CurseForge.

**Spec:** `docs/superpowers/specs/2026-09-28-folioswap-design.md`

**Konventionen:** Lua-Bezeichner in `snake_case`, Kommentare auf Deutsch, Conventional Commits, CalVer `YYYY.M.D`. Jeder Commit endet mit
`Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

---

## Dateistruktur

| Datei | Verantwortung |
|---|---|
| `FolioSwap.toc` | Ladereihenfolge, zugleich Dateiliste für die Tests |
| `Locales/enUS.lua`, `Locales/deDE.lua` | Texte, `ns.L` |
| `Core/Util.lua` | `sorted_keys`, `contains`, `copy` |
| `Core/FolioApi.lua` | einzige Stelle mit `C_Traits` |
| `Core/Presets.lua` | Guide-Presets (Daten) + Validierung |
| `Core/ProfileStore.lua` | eigene Profile, aktives Profil, `FolioSwapDB` |
| `Core/Player.lua` | aktuelle specID |
| `Core/Reporter.lua` | alle Chat-Ausgaben |
| `Core/Actions.lua` | Anwendungsfälle (apply, save, delete, …) |
| `Core/SwapController.lua` | Events + Kampf-Vormerkung |
| `UI/SlashCommands.lua` | `/folio` |
| `UI/FolioPanel.lua` | Leiste am Foliant-Fenster |
| `Core/Bootstrap.lua` | Event-Frame, DB-Init, Verdrahtung |
| `spec/helpers/c_traits_mock.lua` | Fake-Foliant für Tests |
| `spec/helpers/wow_env.lua` | lädt das Addon laut `.toc` in eine Testumgebung |
| `scripts/test.sh` | richtet Lua 5.1 lokal ein, führt luacheck + busted aus |

---

### Task 1: Toolchain und Testgerüst

**Files:**
- Create: `.gitignore`, `.busted`, `.luacheckrc`, `scripts/test.sh`, `FolioSwap.toc`
- Create: `spec/helpers/c_traits_mock.lua`, `spec/helpers/wow_env.lua`
- Test: `spec/wow_env_spec.lua`

- [ ] **Step 1: Konfiguration anlegen**

`.gitignore`:
```
.lua/
.luarocks/
.release/
```

`.busted`:
```lua
return {
  _all = { lpath = "./?.lua" },
  default = { ROOT = { "spec" }, pattern = "_spec" },
}
```

`.luacheckrc`:
```lua
std = "lua51"
max_line_length = 120
exclude_files = { ".lua/**", ".luarocks/**", ".release/**" }

globals = {
  "FolioSwapDB", "SLASH_FOLIOSWAP1", "SLASH_FOLIOSWAP2", "SlashCmdList", "StaticPopupDialogs",
}
read_globals = {
  "C_Traits", "C_Spell", "CreateFrame", "GetLocale", "GetSpecialization", "GetSpecializationInfo",
  "InCombatLockdown", "hooksecurefunc", "StaticPopup_Show", "RunesOfPowerMixin", "ExpansionLandingPage",
  "ACCEPT", "CANCEL",
}

files["spec/**"] = {
  std = "+busted",
  globals = { "C_Traits", "C_Spell", "GetLocale", "InCombatLockdown", "GetSpecialization", "GetSpecializationInfo" },
}
```

`scripts/test.sh`:
```sh
#!/bin/sh
# Richtet beim ersten Lauf Lua 5.1 + busted + luacheck projektlokal ein (.lua/), dann Lint und Tests.
set -eu
cd "$(dirname "$0")/.."
if [ ! -x .lua/bin/busted ]; then
  uvx hererocks .lua -l 5.1 -r latest
  .lua/bin/luarocks install busted
  .lua/bin/luarocks install luacheck
fi
.lua/bin/luacheck .
.lua/bin/busted "$@"
```

`FolioSwap.toc` (Dateiliste wächst mit jedem Task):
```
## Interface: 120100
## Title: FolioSwap
## Notes: Switches your Omnium Folio runes automatically per specialization.
## Notes-deDE: Stellt die Runen des Omniumfolianten automatisch pro Spezialisierung um.
## Author: Madchristian
## Version: @project-version@
## SavedVariables: FolioSwapDB

```

Run: `chmod +x scripts/test.sh`

- [ ] **Step 2: Foliant-Mock schreiben**

`spec/helpers/c_traits_mock.lua`:
```lua
-- Fake-Omniumfoliant: bildet die genutzte C_Traits-API mit einem kleinen Baum nach.
local c_traits_mock = {}

-- Frische Tabelle pro Aufruf, damit Tests sich nicht gegenseitig verändern.
function c_traits_mock.default_tree()
  return {
    config_id = 7,
    nodes = {
      { id = 100, entries = { 1001, 1002 }, active = 1001 },                -- Kern
      { id = 200, entries = { 2001, 2002, 2003 }, active = 2001 },          -- Defensiv
      { id = 300, entries = { 3001 }, active = 3001 },                      -- Lingering, keine Wahl
      { id = 400, entries = { 4001, 4002, 4003, 4004 }, active = 4001 },    -- Sekundärwert
      { id = 500, entries = { 5001, 5002, 5003 }, available = false },      -- Capstone, gesperrt
    },
  }
end

function c_traits_mock.install(tree)
  local state = { set_calls = {}, commits = 0, commit_ok = true, reject = {} }
  local by_id, node_ids = {}, {}
  for _, node in ipairs(tree.nodes) do
    by_id[node.id] = node
    node_ids[#node_ids + 1] = node.id
  end

  C_Traits = {
    GetConfigIDBySystemID = function(system_id)
      if system_id == 48 then return tree.config_id end
    end,
    GetTreeNodes = function(tree_id)
      return tree_id == 1186 and node_ids or {}
    end,
    GetNodeInfo = function(_, node_id)
      local node = by_id[node_id]
      return {
        ID = node_id,
        entryIDs = node.entries,
        activeEntry = node.active and { entryID = node.active, rank = 1 } or nil,
        isAvailable = node.available ~= false,
      }
    end,
    GetEntryInfo = function(_, entry_id)
      return { definitionID = entry_id * 10 }
    end,
    GetDefinitionInfo = function(definition_id)
      return { spellID = definition_id * 10 }
    end,
    SetSelection = function(_, node_id, entry_id)
      table.insert(state.set_calls, { node_id, entry_id })
      if state.reject[node_id] then return false end
      by_id[node_id].active = entry_id
      return true
    end,
    CommitConfig = function()
      state.commits = state.commits + 1
      return state.commit_ok
    end,
  }
  return state
end

return c_traits_mock
```

- [ ] **Step 3: Testumgebung schreiben**

`spec/helpers/wow_env.lua`:
```lua
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
```

- [ ] **Step 4: Smoke-Test für das Gerüst schreiben**

`spec/wow_env_spec.lua`:
```lua
local wow_env = require("spec.helpers.wow_env")

describe("wow_env", function()
  it("stellt den Foliant-Mock bereit", function()
    local env = wow_env.new()
    assert.equals(7, C_Traits.GetConfigIDBySystemID(48))
    assert.same({ 100, 200, 300, 400, 500 }, C_Traits.GetTreeNodes(1186))
    assert.is_table(env.ns)
  end)

  it("übernimmt Kampf- und Spec-Zustand live", function()
    local env = wow_env.new()
    env.in_combat = true
    env.spec_id = 63
    assert.is_true(InCombatLockdown())
    assert.equals(63, GetSpecializationInfo(GetSpecialization()))
  end)
end)
```

- [ ] **Step 5: Tests laufen lassen**

Run: `scripts/test.sh`
Expected: Der erste Lauf installiert Lua 5.1 nach `.lua/`. Danach `0 warnings / 0 errors` von luacheck und `2 successes / 0 failures / 0 errors / 0 pending`.

- [ ] **Step 6: Commit**

```bash
git add .gitignore .busted .luacheckrc scripts/test.sh FolioSwap.toc spec/
git commit -m "chore: Toolchain, TOC und Testgerüst mit Foliant-Mock"
```

---

### Task 2: Locales

**Files:**
- Create: `Locales/enUS.lua`, `Locales/deDE.lua`
- Modify: `FolioSwap.toc` (Dateiliste)
- Test: `spec/locales_spec.lua`

- [ ] **Step 1: Failing Test schreiben**

`spec/locales_spec.lua`:
```lua
local wow_env = require("spec.helpers.wow_env")

describe("Locales", function()
  it("liefert englische Texte als Standard", function()
    assert.equals("Apply", wow_env.new().ns.L.panel_apply)
  end)

  it("überschreibt Texte auf deDE", function()
    assert.equals("Anwenden", wow_env.new({ locale = "deDE" }).ns.L.panel_apply)
  end)

  it("fällt bei fehlenden Schlüsseln auf den Schlüssel zurück", function()
    assert.equals("does_not_exist", wow_env.new().ns.L.does_not_exist)
  end)

  it("übersetzt alle Texte ins Deutsche", function()
    local en = wow_env.new().ns.L
    local de = wow_env.new({ locale = "deDE" }).ns.L
    local same_in_both = { prefix = true, preset_marker = true }
    for key, text in pairs(en) do
      if not same_in_both[key] then
        assert.are_not.equal(text, de[key], key)
      end
    end
  end)
end)
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `scripts/test.sh spec/locales_spec.lua`
Expected: FAIL, `attempt to index field 'L' (a nil value)`

- [ ] **Step 3: Implementieren**

`Locales/enUS.lua`:
```lua
local _, ns = ...

-- Fehlende Schlüssel liefern den Schlüssel selbst, damit nie nil im Chat landet.
local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

L.prefix = "|cff66ccffFolioSwap|r: "
L.applied = "Profile \"%s\" applied (%d rune(s) changed)."
L.unchanged = "Profile \"%s\" is already active in the Omnium Folio."
L.skipped = "%d rune(s) of \"%s\" skipped: %s"
L.reason_unknown = "unknown rune (patch?)"
L.reason_locked = "row still locked"
L.reason_rejected = "rejected by the game"
L.unavailable = "Omnium Folio not unlocked – nothing switched."
L.commit_failed = "Could not save the Omnium Folio changes."
L.combat_pending = "In combat – the Omnium Folio switches after combat."
L.in_combat = "Not possible in combat."
L.no_spec = "No specialization active."
L.saved = "Profile \"%s\" saved."
L.deleted = "Profile \"%s\" deleted."
L.activated = "Profile \"%s\" is now active for this specialization."
L.not_found = "No profile \"%s\" for this specialization."
L.preset_readonly = "Guide preset \"%s\" can't be changed."
L.preset_name = "\"%s\" is the name of a guide preset."
L.empty_name = "Please enter a name."
L.no_profiles = "No profiles for this specialization."
L.list_header = "Profiles for this specialization:"
L.active_marker = " (active)"
L.preset_marker = " [Guide]"
L.dump_saved = "%d rune row(s) written to FolioSwapDB.dump – saved on the next /reload."
L.check_ok = "All guide presets match the current Omnium Folio."
L.check_problem = "Preset \"%s\" (spec %d): node %d / entry %d not found."
L.help = "/folio list | apply <name> | save <name> | delete <name> | active <name> | dump | check"
L.panel_apply = "Apply"
L.panel_save = "Save current…"
L.panel_delete = "Delete"
L.panel_activate = "Set active"
L.save_prompt = "Name for the current Omnium Folio setup:"
```

`Locales/deDE.lua`:
```lua
local _, ns = ...
if GetLocale() ~= "deDE" then return end

local L = ns.L
L.applied = "Profil „%s“ angewendet (%d Rune(n) geändert)."
L.unchanged = "Profil „%s“ ist im Omniumfolianten bereits aktiv."
L.skipped = "%d Rune(n) aus „%s“ übersprungen: %s"
L.reason_unknown = "unbekannte Rune (Patch?)"
L.reason_locked = "Reihe noch gesperrt"
L.reason_rejected = "vom Spiel abgelehnt"
L.unavailable = "Omniumfoliant nicht freigeschaltet – nichts umgestellt."
L.commit_failed = "Die Änderungen am Omniumfolianten konnten nicht gespeichert werden."
L.combat_pending = "Im Kampf – der Omniumfoliant wird nach dem Kampf umgestellt."
L.in_combat = "Im Kampf nicht möglich."
L.no_spec = "Keine Spezialisierung aktiv."
L.saved = "Profil „%s“ gespeichert."
L.deleted = "Profil „%s“ gelöscht."
L.activated = "Profil „%s“ ist jetzt für diese Spezialisierung aktiv."
L.not_found = "Kein Profil „%s“ für diese Spezialisierung."
L.preset_readonly = "Guide-Preset „%s“ kann nicht geändert werden."
L.preset_name = "„%s“ ist der Name eines Guide-Presets."
L.empty_name = "Bitte einen Namen eingeben."
L.no_profiles = "Keine Profile für diese Spezialisierung."
L.list_header = "Profile für diese Spezialisierung:"
L.active_marker = " (aktiv)"
L.dump_saved = "%d Runenreihe(n) in FolioSwapDB.dump geschrieben – gespeichert beim nächsten /reload."
L.check_ok = "Alle Guide-Presets passen zum aktuellen Omniumfolianten."
L.check_problem = "Preset „%s“ (Spec %d): Node %d / Entry %d nicht gefunden."
L.help = "/folio list | apply <Name> | save <Name> | delete <Name> | active <Name> | dump | check"
L.panel_apply = "Anwenden"
L.panel_save = "Aktuelles speichern…"
L.panel_delete = "Löschen"
L.panel_activate = "Als aktiv setzen"
L.save_prompt = "Name für das aktuelle Foliant-Setup:"
```

An `FolioSwap.toc` anhängen:
```
Locales\enUS.lua
Locales\deDE.lua
```

- [ ] **Step 4: Tests laufen lassen**

Run: `scripts/test.sh`
Expected: alle Tests PASS, luacheck ohne Warnungen

- [ ] **Step 5: Commit**

```bash
git add Locales/ FolioSwap.toc spec/locales_spec.lua
git commit -m "feat(locales): englische und deutsche Texte"
```

---

### Task 3: Util

**Files:**
- Create: `Core/Util.lua`
- Modify: `FolioSwap.toc`
- Test: `spec/util_spec.lua`

- [ ] **Step 1: Failing Test schreiben**

`spec/util_spec.lua`:
```lua
local wow_env = require("spec.helpers.wow_env")

describe("util", function()
  local util
  before_each(function() util = wow_env.new().ns.util end)

  it("sortiert Schlüssel", function()
    assert.same({ 1, 2, 10 }, util.sorted_keys({ [10] = "a", [1] = "b", [2] = "c" }))
    assert.same({ "Alpha", "Zeta" }, util.sorted_keys({ Zeta = true, Alpha = true }))
  end)

  it("findet Werte in Listen", function()
    assert.is_true(util.contains({ 1, 2, 3 }, 2))
    assert.is_false(util.contains({ 1, 2, 3 }, 4))
  end)

  it("kopiert Tabellen flach", function()
    local original = { [100] = 1001 }
    local copy = util.copy(original)
    original[100] = 1002
    assert.same({ [100] = 1001 }, copy)
  end)
end)
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `scripts/test.sh spec/util_spec.lua`
Expected: FAIL, `attempt to index local 'util' (a nil value)`

- [ ] **Step 3: Implementieren**

`Core/Util.lua`:
```lua
local _, ns = ...

local util = {}
ns.util = util

function util.sorted_keys(map)
  local keys = {}
  for key in pairs(map) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

function util.contains(list, value)
  for _, item in ipairs(list) do
    if item == value then return true end
  end
  return false
end

function util.copy(map)
  local result = {}
  for key, value in pairs(map) do
    result[key] = value
  end
  return result
end
```

An `FolioSwap.toc` anhängen:
```
Core\Util.lua
```

- [ ] **Step 4: Tests laufen lassen**

Run: `scripts/test.sh`
Expected: alle Tests PASS

- [ ] **Step 5: Commit**

```bash
git add Core/Util.lua FolioSwap.toc spec/util_spec.lua
git commit -m "feat(core): Hilfsfunktionen für Schlüssel, Listen und Kopien"
```

---

### Task 4: FolioApi

**Files:**
- Create: `Core/FolioApi.lua`
- Modify: `FolioSwap.toc`
- Test: `spec/folio_api_spec.lua`

- [ ] **Step 1: Failing Test schreiben**

`spec/folio_api_spec.lua`:
```lua
local wow_env = require("spec.helpers.wow_env")

local LOCKED_FOLIO = { config_id = nil, nodes = {} }

describe("folio_api", function()
  local env, api
  before_each(function()
    env = wow_env.new()
    api = env.ns.folio_api
  end)

  it("ist ohne Config-ID nicht verfügbar", function()
    local locked = wow_env.new({ tree = LOCKED_FOLIO }).ns.folio_api
    assert.is_false(locked.is_available())
    assert.is_nil(locked.read_current())
    assert.is_nil(locked.catalog())
    assert.is_nil(locked.dump())
    assert.equals("unavailable", locked.apply({ [100] = 1002 }).reason)
  end)

  it("ist mit Config-ID verfügbar", function()
    assert.is_true(api.is_available())
  end)

  it("liest nur Nodes mit echter Auswahl und gesetzter Rune", function()
    assert.same({ [100] = 1001, [200] = 2001, [400] = 4001 }, api.read_current())
  end)

  it("liefert den Katalog aller Auswahl-Nodes", function()
    local catalog = api.catalog()
    assert.same({ 4001, 4002, 4003, 4004 }, catalog[400])
    assert.same({ 5001, 5002, 5003 }, catalog[500])
    assert.is_nil(catalog[300])
  end)

  it("setzt nur abweichende Runen und committet einmal", function()
    local result = api.apply({ [100] = 1002, [200] = 2001, [400] = 4003 })
    assert.same({ 100, 400 }, result.applied)
    assert.same({}, result.skipped)
    assert.is_nil(result.reason)
    assert.same({ { 100, 1002 }, { 400, 4003 } }, env.traits.set_calls)
    assert.equals(1, env.traits.commits)
  end)

  it("committet nicht, wenn alles schon passt", function()
    local result = api.apply({ [100] = 1001 })
    assert.same({}, result.applied)
    assert.same({}, result.skipped)
    assert.equals(0, env.traits.commits)
  end)

  it("überspringt unbekannte, gesperrte und abgelehnte Runen", function()
    env.traits.reject[200] = true
    local result = api.apply({ [100] = 9999, [200] = 2002, [500] = 5001, [777] = 1 })
    assert.same({
      { node_id = 100, reason = "unknown" },
      { node_id = 200, reason = "rejected" },
      { node_id = 500, reason = "locked" },
      { node_id = 777, reason = "unknown" },
    }, result.skipped)
    assert.equals(0, env.traits.commits)
  end)

  it("meldet einen fehlgeschlagenen Commit", function()
    env.traits.commit_ok = false
    assert.equals("commit_failed", api.apply({ [100] = 1002 }).reason)
  end)

  it("gibt beim Dump Nodes, Entries und Runennamen aus", function()
    local rows = api.dump()
    assert.equals(4, #rows)
    assert.equals(100, rows[1].node_id)
    assert.same({ entry_id = 1001, name = "Spell 100100" }, rows[1].entries[1])
  end)
end)
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `scripts/test.sh spec/folio_api_spec.lua`
Expected: FAIL, `attempt to index local 'api' (a nil value)`

- [ ] **Step 3: Implementieren**

`Core/FolioApi.lua`:
```lua
local _, ns = ...
local util = ns.util

-- Werte aus Blizzard_MidnightLandingPage.lua (Build 12.1.0): intern heißt der Omniumfoliant "Runes of Power".
local SYSTEM_ID = 48
local TREE_ID = 1186

local folio_api = {}
ns.folio_api = folio_api

local function current_config_id()
  return C_Traits.GetConfigIDBySystemID(SYSTEM_ID)
end

-- Nur Nodes mit echter Auswahl; die Reihe ohne Wahl (Rune of Lingering) fällt heraus.
local function choice_nodes(config_id)
  local nodes = {}
  for _, node_id in ipairs(C_Traits.GetTreeNodes(TREE_ID)) do
    local info = C_Traits.GetNodeInfo(config_id, node_id)
    if info and info.entryIDs and #info.entryIDs > 1 then
      nodes[node_id] = info
    end
  end
  return nodes
end

local function active_entry_id(info)
  return info.activeEntry and info.activeEntry.entryID
end

local function entry_name(config_id, entry_id)
  local entry = C_Traits.GetEntryInfo(config_id, entry_id)
  local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
  if not definition then return "?" end
  return definition.overrideName or (definition.spellID and C_Spell.GetSpellName(definition.spellID)) or "?"
end

-- Ergebnis: "applied", "unchanged" oder ein Grund zum Überspringen.
local function apply_selection(config_id, info, node_id, entry_id)
  if not info or not util.contains(info.entryIDs, entry_id) then return "unknown" end
  if active_entry_id(info) == entry_id then return "unchanged" end
  if not info.isAvailable then return "locked" end
  if C_Traits.SetSelection(config_id, node_id, entry_id) then return "applied" end
  return "rejected"
end

function folio_api.is_available()
  return current_config_id() ~= nil
end

function folio_api.read_current()
  local config_id = current_config_id()
  if not config_id then return nil end
  local selections = {}
  for node_id, info in pairs(choice_nodes(config_id)) do
    selections[node_id] = active_entry_id(info)
  end
  return selections
end

function folio_api.catalog()
  local config_id = current_config_id()
  if not config_id then return nil end
  local catalog = {}
  for node_id, info in pairs(choice_nodes(config_id)) do
    catalog[node_id] = info.entryIDs
  end
  return catalog
end

function folio_api.apply(selections)
  local result = { applied = {}, skipped = {} }
  local config_id = current_config_id()
  if not config_id then
    result.reason = "unavailable"
    return result
  end

  local nodes = choice_nodes(config_id)
  for _, node_id in ipairs(util.sorted_keys(selections)) do
    local outcome = apply_selection(config_id, nodes[node_id], node_id, selections[node_id])
    if outcome == "applied" then
      table.insert(result.applied, node_id)
    elseif outcome ~= "unchanged" then
      table.insert(result.skipped, { node_id = node_id, reason = outcome })
    end
  end

  if #result.applied > 0 and not C_Traits.CommitConfig(config_id) then
    result.reason = "commit_failed"
  end
  return result
end

function folio_api.dump()
  local config_id = current_config_id()
  if not config_id then return nil end
  local nodes = choice_nodes(config_id)
  local rows = {}
  for _, node_id in ipairs(util.sorted_keys(nodes)) do
    local entries = {}
    for _, entry_id in ipairs(nodes[node_id].entryIDs) do
      entries[#entries + 1] = { entry_id = entry_id, name = entry_name(config_id, entry_id) }
    end
    rows[#rows + 1] = { node_id = node_id, entries = entries }
  end
  return rows
end
```

An `FolioSwap.toc` anhängen:
```
Core\FolioApi.lua
```

- [ ] **Step 4: Tests laufen lassen**

Run: `scripts/test.sh`
Expected: alle Tests PASS

- [ ] **Step 5: Commit**

```bash
git add Core/FolioApi.lua FolioSwap.toc spec/folio_api_spec.lua
git commit -m "feat(core): FolioApi liest, setzt und listet Foliant-Runen"
```

---

### Task 5: Presets

**Files:**
- Create: `Core/Presets.lua`
- Modify: `FolioSwap.toc`
- Test: `spec/presets_spec.lua`

- [ ] **Step 1: Failing Test schreiben**

`spec/presets_spec.lua`:
```lua
local wow_env = require("spec.helpers.wow_env")

local function sample_presets()
  return {
    [62] = { { name = "Guide M+", selections = { [100] = 1002, [400] = 4003 } } },
    [63] = { { name = "Guide Raid", selections = { [100] = 1001, [900] = 9001 } } },
  }
end

describe("presets", function()
  local env, presets
  before_each(function()
    env = wow_env.new({ presets = sample_presets() })
    presets = env.ns.presets
  end)

  it("liefert die Presets einer Spec als schreibgeschützte Profile", function()
    local list = presets.for_spec(62)
    assert.equals(1, #list)
    assert.equals("Guide M+", list[1].name)
    assert.equals("preset", list[1].source)
    assert.equals(1002, list[1].selections[100])
  end)

  it("liefert eine leere Liste für Specs ohne Presets", function()
    assert.same({}, presets.for_spec(64))
  end)

  it("findet Presets per Name", function()
    assert.equals("Guide M+", presets.find(62, "Guide M+").name)
    assert.is_nil(presets.find(62, "Gibt es nicht"))
  end)

  it("meldet Einträge, die nicht im Foliant vorkommen", function()
    assert.same(
      { { spec_id = 63, name = "Guide Raid", node_id = 900, entry_id = 9001 } },
      presets.validate(env.ns.folio_api.catalog())
    )
  end)

  it("ausgelieferte Presets haben pro Spec eindeutige, nicht leere Namen", function()
    for spec_id, list in pairs(wow_env.new().ns.presets.data) do
      local seen = {}
      for _, preset in ipairs(list) do
        assert.is_true(type(preset.name) == "string" and preset.name ~= "", "Name fehlt in Spec " .. spec_id)
        assert.is_nil(seen[preset.name], "Doppelter Name " .. tostring(preset.name))
        assert.is_table(preset.selections)
        seen[preset.name] = true
      end
    end
  end)
end)
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `scripts/test.sh spec/presets_spec.lua`
Expected: FAIL, `attempt to index local 'presets' (a nil value)`

- [ ] **Step 3: Implementieren**

`Core/Presets.lua`:
```lua
local _, ns = ...
local util = ns.util

local presets = {}
ns.presets = presets

-- Guide-Empfehlungen: [spec_id] = { { name = "...", selections = { [node_id] = entry_id } } }
-- Die IDs stammen aus /folio dump; Quellen und Pflege stehen in docs/presets.md.
presets.data = {}

function presets.for_spec(spec_id)
  local profiles = {}
  for _, preset in ipairs(presets.data[spec_id] or {}) do
    profiles[#profiles + 1] = { name = preset.name, source = "preset", selections = preset.selections }
  end
  return profiles
end

function presets.find(spec_id, name)
  for _, profile in ipairs(presets.for_spec(spec_id)) do
    if profile.name == name then return profile end
  end
  return nil
end

-- catalog: [node_id] = { entry_id, ... } aus folio_api.catalog()
function presets.validate(catalog)
  local problems = {}
  for _, spec_id in ipairs(util.sorted_keys(presets.data)) do
    for _, preset in ipairs(presets.data[spec_id]) do
      for _, node_id in ipairs(util.sorted_keys(preset.selections)) do
        local entry_id = preset.selections[node_id]
        if not util.contains(catalog[node_id] or {}, entry_id) then
          problems[#problems + 1] = { spec_id = spec_id, name = preset.name, node_id = node_id, entry_id = entry_id }
        end
      end
    end
  end
  return problems
end
```

An `FolioSwap.toc` anhängen:
```
Core\Presets.lua
```

- [ ] **Step 4: Tests laufen lassen**

Run: `scripts/test.sh`
Expected: alle Tests PASS

- [ ] **Step 5: Commit**

```bash
git add Core/Presets.lua FolioSwap.toc spec/presets_spec.lua
git commit -m "feat(core): Guide-Presets mit Validierung gegen den Foliant"
```

---

### Task 6: ProfileStore

**Files:**
- Create: `Core/ProfileStore.lua`
- Modify: `FolioSwap.toc`
- Test: `spec/profile_store_spec.lua`

- [ ] **Step 1: Failing Test schreiben**

`spec/profile_store_spec.lua`:
```lua
local wow_env = require("spec.helpers.wow_env")

local function sample_presets()
  return { [62] = { { name = "Guide M+", selections = { [100] = 1002 } } } }
end

describe("profile_store", function()
  local store
  before_each(function()
    store = wow_env.new({ presets = sample_presets() }).ns.profile_store
  end)

  it("legt fehlende Tabellen beim Init an", function()
    assert.same({ version = 1, profiles = {}, active = {} }, store.init(nil))
  end)

  it("behält vorhandene Daten beim Init", function()
    local db = store.init({ version = 1, profiles = { [62] = {} }, active = { [62] = "Alt" } })
    assert.equals("Alt", db.active[62])
    assert.equals(db, store.db)
  end)

  it("listet Presets vor eigenen Profilen, eigene alphabetisch", function()
    store.save(62, "Zeta", { [100] = 1001 })
    store.save(62, "Alpha", { [100] = 1001 })
    local names = {}
    for _, profile in ipairs(store.list(62)) do names[#names + 1] = profile.name end
    assert.same({ "Guide M+", "Alpha", "Zeta" }, names)
  end)

  it("speichert eine Kopie der Auswahl als eigenes Profil", function()
    local selections = { [100] = 1001 }
    assert.is_true(store.save(62, "Mein", selections))
    selections[100] = 1002
    local profile = store.get(62, "Mein")
    assert.equals(1001, profile.selections[100])
    assert.equals("user", profile.source)
  end)

  it("lehnt leere Namen und Preset-Namen ab", function()
    assert.same({ false, "empty_name" }, { store.save(62, "", {}) })
    assert.same({ false, "preset_name" }, { store.save(62, "Guide M+", {}) })
  end)

  it("löscht eigene Profile und setzt das aktive Profil zurück", function()
    store.save(62, "Mein", { [100] = 1001 })
    store.set_active(62, "Mein")
    assert.is_true(store.delete(62, "Mein"))
    assert.is_nil(store.get(62, "Mein"))
    assert.equals("Guide M+", store.active_name(62))
  end)

  it("schützt Presets und meldet unbekannte Profile beim Löschen", function()
    assert.same({ false, "preset_readonly" }, { store.delete(62, "Guide M+") })
    assert.same({ false, "not_found" }, { store.delete(62, "Gibt es nicht") })
  end)

  it("nimmt ohne gesetztes aktives Profil das erste Preset", function()
    assert.equals("Guide M+", store.get_active(62).name)
    assert.is_nil(store.get_active(63))
  end)

  it("setzt nur existierende Profile aktiv", function()
    assert.same({ false, "not_found" }, { store.set_active(62, "Fehlt") })
    store.save(62, "Mein", { [100] = 1001 })
    assert.is_true(store.set_active(62, "Mein"))
    assert.equals("Mein", store.get_active(62).name)
  end)
end)
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `scripts/test.sh spec/profile_store_spec.lua`
Expected: FAIL, `attempt to index local 'store' (a nil value)`

- [ ] **Step 3: Implementieren**

`Core/ProfileStore.lua`:
```lua
local _, ns = ...
local util = ns.util
local presets = ns.presets

local DB_VERSION = 1

local profile_store = {}
ns.profile_store = profile_store

function profile_store.init(db)
  db = db or {}
  db.version = db.version or DB_VERSION
  db.profiles = db.profiles or {}
  db.active = db.active or {}
  profile_store.db = db
  return db
end

local function own_profiles(spec_id)
  return profile_store.db.profiles[spec_id] or {}
end

function profile_store.list(spec_id)
  local list = presets.for_spec(spec_id)
  local own = own_profiles(spec_id)
  for _, name in ipairs(util.sorted_keys(own)) do
    list[#list + 1] = own[name]
  end
  return list
end

function profile_store.get(spec_id, name)
  return presets.find(spec_id, name) or own_profiles(spec_id)[name]
end

function profile_store.save(spec_id, name, selections)
  if not name or name == "" then return false, "empty_name" end
  if presets.find(spec_id, name) then return false, "preset_name" end
  local profiles = profile_store.db.profiles
  profiles[spec_id] = profiles[spec_id] or {}
  profiles[spec_id][name] = { name = name, source = "user", selections = util.copy(selections) }
  return true
end

function profile_store.delete(spec_id, name)
  if presets.find(spec_id, name) then return false, "preset_readonly" end
  local own = own_profiles(spec_id)
  if not own[name] then return false, "not_found" end
  own[name] = nil
  if profile_store.db.active[spec_id] == name then
    profile_store.db.active[spec_id] = nil
  end
  return true
end

function profile_store.set_active(spec_id, name)
  if not profile_store.get(spec_id, name) then return false, "not_found" end
  profile_store.db.active[spec_id] = name
  return true
end

-- Ohne gültiges aktives Profil gilt das erste Preset der Spec.
function profile_store.active_name(spec_id)
  local name = profile_store.db.active[spec_id]
  if name and profile_store.get(spec_id, name) then return name end
  local first_preset = presets.for_spec(spec_id)[1]
  return first_preset and first_preset.name
end

function profile_store.get_active(spec_id)
  local name = profile_store.active_name(spec_id)
  return name and profile_store.get(spec_id, name)
end
```

An `FolioSwap.toc` anhängen:
```
Core\ProfileStore.lua
```

- [ ] **Step 4: Tests laufen lassen**

Run: `scripts/test.sh`
Expected: alle Tests PASS

- [ ] **Step 5: Commit**

```bash
git add Core/ProfileStore.lua FolioSwap.toc spec/profile_store_spec.lua
git commit -m "feat(core): ProfileStore für eigene und aktive Profile pro Spec"
```

---

### Task 7: Player und Reporter

**Files:**
- Create: `Core/Player.lua`, `Core/Reporter.lua`
- Modify: `FolioSwap.toc`
- Test: `spec/player_spec.lua`, `spec/reporter_spec.lua`

- [ ] **Step 1: Failing Tests schreiben**

`spec/player_spec.lua`:
```lua
local wow_env = require("spec.helpers.wow_env")

describe("player", function()
  it("liefert die specID der aktiven Spezialisierung", function()
    assert.equals(62, wow_env.new({ spec_id = 62 }).ns.player.current_spec_id())
  end)

  it("liefert nil ohne Spezialisierung", function()
    local env = wow_env.new()
    env.spec_id = nil
    assert.is_nil(env.ns.player.current_spec_id())
  end)
end)
```

`spec/reporter_spec.lua`:
```lua
local wow_env = require("spec.helpers.wow_env")

local PROFILE = { name = "Guide M+" }

describe("reporter", function()
  local env, reporter
  before_each(function()
    env = wow_env.new()
    reporter = env.ns.reporter
  end)

  it("meldet angewendete Runen mit Präfix", function()
    reporter.report_apply(PROFILE, { applied = { 100, 400 }, skipped = {} })
    assert.same({ "|cff66ccffFolioSwap|r: Profile \"Guide M+\" applied (2 rune(s) changed)." }, env.messages)
  end)

  it("schweigt, wenn nichts zu tun war", function()
    reporter.report_apply(PROFILE, { applied = {}, skipped = {} })
    assert.same({}, env.messages)
  end)

  it("meldet auf Wunsch, dass schon alles passt", function()
    reporter.report_apply(PROFILE, { applied = {}, skipped = {} }, true)
    assert.matches("already active", env.messages[1])
  end)

  it("listet übersprungene Runen mit Grund", function()
    reporter.report_apply(PROFILE, { applied = {}, skipped = { { node_id = 500, reason = "locked" } } })
    assert.matches("500 %(row still locked%)", env.messages[1])
  end)

  it("meldet den fehlenden Foliant nur einmal pro Sitzung", function()
    reporter.report_apply(PROFILE, { applied = {}, skipped = {}, reason = "unavailable" })
    reporter.report_apply(PROFILE, { applied = {}, skipped = {}, reason = "unavailable" })
    assert.equals(1, #env.messages)
  end)

  it("meldet einen fehlgeschlagenen Commit", function()
    reporter.report_apply(PROFILE, { applied = { 100 }, skipped = {}, reason = "commit_failed" })
    assert.matches("Could not save", env.messages[2])
  end)

  it("beschriftet Profile mit Guide- und Aktiv-Markierung", function()
    local preset = { name = "Guide M+", source = "preset" }
    assert.equals("Guide M+ [Guide] (active)", reporter.profile_label(preset, "Guide M+"))
    assert.equals("Mein", reporter.profile_label({ name = "Mein", source = "user" }, "Guide M+"))
  end)
end)
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

Run: `scripts/test.sh spec/player_spec.lua spec/reporter_spec.lua`
Expected: FAIL, `attempt to index field 'player' (a nil value)` bzw. `'reporter'`

- [ ] **Step 3: Implementieren**

`Core/Player.lua`:
```lua
local _, ns = ...

local player = {}
ns.player = player

function player.current_spec_id()
  local index = GetSpecialization()
  if not index then return nil end
  return (GetSpecializationInfo(index))
end
```

`Core/Reporter.lua`:
```lua
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

-- verbose: auch melden, wenn das Profil schon komplett gesetzt war (manuelles Anwenden).
function reporter.report_apply(profile, result, verbose)
  if result.reason == "unavailable" then return reporter.report_unavailable() end
  if #result.applied > 0 then
    reporter.say(L.applied:format(profile.name, #result.applied))
  elseif verbose and #result.skipped == 0 then
    reporter.say(L.unchanged:format(profile.name))
  end
  if #result.skipped > 0 then
    reporter.say(L.skipped:format(#result.skipped, profile.name, describe_skipped(result.skipped)))
  end
  if result.reason == "commit_failed" then
    reporter.say(L.commit_failed)
  end
end
```

An `FolioSwap.toc` anhängen:
```
Core\Player.lua
Core\Reporter.lua
```

- [ ] **Step 4: Tests laufen lassen**

Run: `scripts/test.sh`
Expected: alle Tests PASS

- [ ] **Step 5: Commit**

```bash
git add Core/Player.lua Core/Reporter.lua FolioSwap.toc spec/player_spec.lua spec/reporter_spec.lua
git commit -m "feat(core): Spec-Ermittlung und Chat-Meldungen"
```

---

### Task 8: Actions

**Files:**
- Create: `Core/Actions.lua`
- Modify: `FolioSwap.toc`
- Test: `spec/actions_spec.lua`

- [ ] **Step 1: Failing Test schreiben**

`spec/actions_spec.lua`:
```lua
local wow_env = require("spec.helpers.wow_env")

local function sample_presets()
  return { [62] = { { name = "Guide M+", selections = { [100] = 1002, [400] = 4003 } } } }
end

describe("actions", function()
  local env, actions
  before_each(function()
    env = wow_env.new({ presets = sample_presets() })
    actions = env.ns.actions
  end)

  local function last_message()
    return env.messages[#env.messages]
  end

  it("wendet ein Profil per Name an", function()
    actions.apply("Guide M+")
    assert.same({ { 100, 1002 }, { 400, 4003 } }, env.traits.set_calls)
    assert.matches("applied %(2 rune", last_message())
  end)

  it("meldet beim manuellen Anwenden, wenn schon alles passt", function()
    actions.apply("Guide M+")
    actions.apply("Guide M+")
    assert.matches("already active", last_message())
  end)

  it("wendet im Kampf nichts an", function()
    env.in_combat = true
    actions.apply("Guide M+")
    assert.same({}, env.traits.set_calls)
    assert.matches("combat", last_message())
  end)

  it("meldet unbekannte Profile", function()
    actions.apply("Fehlt")
    assert.matches("No profile \"Fehlt\"", last_message())
  end)

  it("speichert den aktuellen Foliant als eigenes Profil", function()
    actions.save_current("Mein Setup")
    local profile = env.ns.profile_store.get(62, "Mein Setup")
    assert.same({ [100] = 1001, [200] = 2001, [400] = 4001 }, profile.selections)
    assert.matches("saved", last_message())
  end)

  it("meldet Fehler beim Speichern unter einem Preset-Namen", function()
    actions.save_current("Guide M+")
    assert.matches("guide preset", last_message())
  end)

  it("aktiviert und löscht Profile mit Rückmeldung", function()
    actions.save_current("Mein Setup")
    actions.set_active("Mein Setup")
    assert.matches("now active", last_message())
    actions.delete("Mein Setup")
    assert.matches("deleted", last_message())
  end)

  it("listet Profile mit Markierungen", function()
    actions.save_current("Mein Setup")
    actions.list()
    assert.equals("  Guide M+ [Guide] (active)", env.messages[#env.messages - 1])
    assert.equals("  Mein Setup", last_message())
  end)

  it("gibt ohne Spezialisierung einen Hinweis", function()
    env.spec_id = nil
    actions.list()
    assert.matches("No specialization", last_message())
  end)

  it("wendet automatisch das aktive Profil an und schweigt danach", function()
    actions.apply_active()
    assert.equals(2, #env.traits.set_calls)
    local message_count = #env.messages
    actions.apply_active()
    assert.equals(message_count, #env.messages)
  end)

  it("speichert den Dump in der Datenbank", function()
    actions.dump()
    assert.equals(4, #env.ns.profile_store.db.dump)
    assert.matches("4 rune row", last_message())
  end)

  it("prüft die Presets gegen den Foliant", function()
    actions.check()
    assert.matches("All guide presets match", last_message())
    env.ns.presets.data[63] = { { name = "Kaputt", selections = { [900] = 9001 } } }
    actions.check()
    assert.matches("node 900 / entry 9001", last_message())
  end)
end)
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `scripts/test.sh spec/actions_spec.lua`
Expected: FAIL, `attempt to index local 'actions' (a nil value)`

- [ ] **Step 3: Implementieren**

`Core/Actions.lua`:
```lua
local _, ns = ...
local L = ns.L
local folio_api = ns.folio_api
local presets = ns.presets
local profile_store = ns.profile_store
local player = ns.player
local reporter = ns.reporter

-- Gemeinsame Anwendungsfälle für Slash-Befehle, Panel und Automatik.
local actions = {}
ns.actions = actions

local function with_spec(handler)
  return function(...)
    local spec_id = player.current_spec_id()
    if not spec_id then return reporter.say(L.no_spec) end
    return handler(spec_id, ...)
  end
end

local function say_result(ok, err, success_text, name)
  reporter.say(ok and success_text:format(name) or L[err]:format(name))
end

local function apply_profile(profile, verbose)
  reporter.report_apply(profile, folio_api.apply(profile.selections), verbose)
end

actions.apply = with_spec(function(spec_id, name)
  if InCombatLockdown() then return reporter.say(L.in_combat) end
  local profile = profile_store.get(spec_id, name)
  if not profile then return reporter.say(L.not_found:format(name)) end
  apply_profile(profile, true)
end)

actions.save_current = with_spec(function(spec_id, name)
  local selections = folio_api.read_current()
  if not selections then return reporter.report_unavailable() end
  local ok, err = profile_store.save(spec_id, name, selections)
  say_result(ok, err, L.saved, name)
end)

actions.delete = with_spec(function(spec_id, name)
  local ok, err = profile_store.delete(spec_id, name)
  say_result(ok, err, L.deleted, name)
end)

actions.set_active = with_spec(function(spec_id, name)
  local ok, err = profile_store.set_active(spec_id, name)
  say_result(ok, err, L.activated, name)
end)

actions.list = with_spec(function(spec_id)
  local profiles = profile_store.list(spec_id)
  if #profiles == 0 then return reporter.say(L.no_profiles) end
  local active_name = profile_store.active_name(spec_id)
  reporter.say(L.list_header)
  for _, profile in ipairs(profiles) do
    reporter.say_line("  " .. reporter.profile_label(profile, active_name))
  end
end)

-- Automatik: leise, solange nichts umgestellt werden muss.
function actions.apply_active()
  local spec_id = player.current_spec_id()
  local profile = spec_id and profile_store.get_active(spec_id)
  if profile then apply_profile(profile, false) end
end

function actions.dump()
  local rows = folio_api.dump()
  if not rows then return reporter.report_unavailable() end
  profile_store.db.dump = rows
  reporter.say(L.dump_saved:format(#rows))
end

function actions.check()
  local catalog = folio_api.catalog()
  if not catalog then return reporter.report_unavailable() end
  local problems = presets.validate(catalog)
  if #problems == 0 then return reporter.say(L.check_ok) end
  for _, problem in ipairs(problems) do
    reporter.say(L.check_problem:format(problem.name, problem.spec_id, problem.node_id, problem.entry_id))
  end
end

function actions.help()
  reporter.say(L.help)
end
```

An `FolioSwap.toc` anhängen:
```
Core\Actions.lua
```

- [ ] **Step 4: Tests laufen lassen**

Run: `scripts/test.sh`
Expected: alle Tests PASS

- [ ] **Step 5: Commit**

```bash
git add Core/Actions.lua FolioSwap.toc spec/actions_spec.lua
git commit -m "feat(core): Aktionen zum Anwenden, Speichern, Löschen und Prüfen"
```

---

### Task 9: SwapController

**Files:**
- Create: `Core/SwapController.lua`
- Modify: `FolioSwap.toc`
- Test: `spec/swap_controller_spec.lua`

- [ ] **Step 1: Failing Test schreiben**

`spec/swap_controller_spec.lua`:
```lua
local wow_env = require("spec.helpers.wow_env")

local function sample_presets()
  return { [62] = { { name = "Guide M+", selections = { [100] = 1002 } } } }
end

describe("swap_controller", function()
  local env, controller
  before_each(function()
    env = wow_env.new({ presets = sample_presets() })
    controller = env.ns.swap_controller
  end)

  it("stellt beim Spec-Wechsel des Spielers um", function()
    controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "player")
    assert.same({ { 100, 1002 } }, env.traits.set_calls)
  end)

  it("ignoriert Spec-Wechsel anderer Einheiten", function()
    controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "party1")
    assert.same({}, env.traits.set_calls)
  end)

  it("stellt bei Login und Reload um, nicht bei Ladebildschirmen", function()
    controller.on_event("PLAYER_ENTERING_WORLD", false, false)
    assert.same({}, env.traits.set_calls)
    controller.on_event("PLAYER_ENTERING_WORLD", true, false)
    assert.equals(1, #env.traits.set_calls)
  end)

  it("merkt im Kampf vor und stellt nach dem Kampf einmal um", function()
    env.in_combat = true
    controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "player")
    controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "player")
    assert.same({}, env.traits.set_calls)
    assert.equals(1, #env.messages)
    assert.matches("after combat", env.messages[1])

    env.in_combat = false
    controller.on_event("PLAYER_REGEN_ENABLED")
    assert.same({ { 100, 1002 } }, env.traits.set_calls)
    controller.on_event("PLAYER_REGEN_ENABLED")
    assert.equals(1, #env.traits.set_calls)
  end)

  it("nennt die benötigten Events", function()
    assert.same(
      { "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED" },
      controller.EVENTS
    )
  end)
end)
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `scripts/test.sh spec/swap_controller_spec.lua`
Expected: FAIL, `attempt to index local 'controller' (a nil value)`

- [ ] **Step 3: Implementieren**

`Core/SwapController.lua`:
```lua
local _, ns = ...
local L = ns.L

local swap_controller = { pending = false }
ns.swap_controller = swap_controller

swap_controller.EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED" }

-- Im Kampf lässt sich der Foliant nicht ändern: vormerken und bei Kampfende nachholen.
function swap_controller.request_apply()
  if not InCombatLockdown() then
    swap_controller.pending = false
    return ns.actions.apply_active()
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
  end
end
```

An `FolioSwap.toc` anhängen:
```
Core\SwapController.lua
```

- [ ] **Step 4: Tests laufen lassen**

Run: `scripts/test.sh`
Expected: alle Tests PASS

- [ ] **Step 5: Commit**

```bash
git add Core/SwapController.lua FolioSwap.toc spec/swap_controller_spec.lua
git commit -m "feat(core): automatisches Umstellen bei Spec-Wechsel und nach Kampfende"
```

---

### Task 10: Slash-Befehle

**Files:**
- Create: `UI/SlashCommands.lua`
- Modify: `FolioSwap.toc`
- Test: `spec/slash_commands_spec.lua`

- [ ] **Step 1: Failing Test schreiben**

`spec/slash_commands_spec.lua`:
```lua
local wow_env = require("spec.helpers.wow_env")

describe("slash_commands", function()
  local env
  before_each(function() env = wow_env.new() end)

  it("registriert /folio und /folioswap", function()
    assert.equals(env.ns.slash_commands.handle, SlashCmdList.FOLIOSWAP)
    assert.equals("/folio", SLASH_FOLIOSWAP1)
    assert.equals("/folioswap", SLASH_FOLIOSWAP2)
  end)

  it("reicht Profilnamen mit Leerzeichen durch", function()
    SlashCmdList.FOLIOSWAP("save  Mein M+ Setup  ")
    assert.is_table(env.ns.profile_store.get(62, "Mein M+ Setup"))
  end)

  it("ignoriert Groß- und Kleinschreibung beim Befehl", function()
    SlashCmdList.FOLIOSWAP("SAVE Mein")
    SlashCmdList.FOLIOSWAP("LIST")
    assert.equals("  Mein", env.messages[#env.messages])
  end)

  it("zeigt bei unbekannten oder leeren Befehlen die Hilfe", function()
    SlashCmdList.FOLIOSWAP("quatsch")
    assert.matches("/folio list", env.messages[#env.messages])
    SlashCmdList.FOLIOSWAP("")
    assert.equals(2, #env.messages)
  end)
end)
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `scripts/test.sh spec/slash_commands_spec.lua`
Expected: FAIL, `attempt to index field 'slash_commands' (a nil value)`

- [ ] **Step 3: Implementieren**

`UI/SlashCommands.lua`:
```lua
local _, ns = ...
local actions = ns.actions

local slash_commands = {}
ns.slash_commands = slash_commands

local HANDLERS = {
  list = actions.list,
  apply = actions.apply,
  save = actions.save_current,
  delete = actions.delete,
  active = actions.set_active,
  dump = actions.dump,
  check = actions.check,
  help = actions.help,
}

function slash_commands.handle(input)
  local command, argument = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  local handler = HANDLERS[command:lower()] or actions.help
  handler(argument)
end

SLASH_FOLIOSWAP1 = "/folio"
SLASH_FOLIOSWAP2 = "/folioswap"
SlashCmdList.FOLIOSWAP = slash_commands.handle
```

An `FolioSwap.toc` anhängen:
```
UI\SlashCommands.lua
```

- [ ] **Step 4: Tests laufen lassen**

Run: `scripts/test.sh`
Expected: alle Tests PASS

- [ ] **Step 5: Commit**

```bash
git add UI/SlashCommands.lua FolioSwap.toc spec/slash_commands_spec.lua
git commit -m "feat(ui): Slash-Befehle /folio und /folioswap"
```

---

### Task 11: Panel und Bootstrap

Reiner Frame-Code ohne Unit-Tests (siehe Spec); Prüfung über luacheck und ingame in Task 12.

**Files:**
- Create: `UI/FolioPanel.lua`, `Core/Bootstrap.lua`
- Modify: `FolioSwap.toc`

- [ ] **Step 1: Panel schreiben**

`UI/FolioPanel.lua`:
```lua
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
  panel:SetPoint("TOP", parent, "BOTTOM", 0, -4)

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
```

- [ ] **Step 2: Bootstrap schreiben**

`Core/Bootstrap.lua`:
```lua
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
```

An `FolioSwap.toc` anhängen (Bootstrap zuletzt):
```
UI\FolioPanel.lua
Core\Bootstrap.lua
```

- [ ] **Step 3: Lint und Tests laufen lassen**

Run: `scripts/test.sh`
Expected: luacheck `0 warnings / 0 errors`, alle Tests PASS (Panel und Bootstrap werden von `wow_env` übersprungen)

- [ ] **Step 4: Commit**

```bash
git add UI/FolioPanel.lua Core/Bootstrap.lua FolioSwap.toc
git commit -m "feat(ui): Profil-Leiste am Omniumfolianten und Addon-Start"
```

---

### Task 12: Ingame-Test und Runen-Dump (Checkpoint mit dem User)

Dieser Task braucht den User am Spiel. Der Agent bereitet vor, der User spielt, der Agent wertet aus.

- [ ] **Step 1: Addon verlinken**

```bash
ln -s ~/Projects/folio-swap "/Applications/World of Warcraft/_retail_/Interface/AddOns/FolioSwap"
```
Expected: kein Fehler; `ls -l ".../AddOns/FolioSwap"` zeigt den Link.

- [ ] **Step 2: User testet ingame (Checkliste an den User geben)**

1. Einloggen mit einem Charakter, der den Foliant freigeschaltet hat → keine Lua-Fehler (BugGrabber ist installiert)
2. `/folio dump`, danach `/reload`
3. `/folio save Test`, `/folio list` → „Test“ erscheint
4. Foliant öffnen (Midnight-Landingpage) → Leiste mit Dropdown und vier Buttons sichtbar
5. Eine Rune per Hand ändern, im Panel „Test“ wählen, „Anwenden“ → Rune springt zurück, Chat meldet Anwendung
6. „Test“ als aktiv setzen, Spec wechseln, zurückwechseln → Foliant stellt sich auf „Test“ um
7. Im Kampf (Trainingspuppe) Spec wechseln → Hinweis „nach dem Kampf“, Umstellung nach Kampfende

- [ ] **Step 3: Dump auswerten**

Datei lesen: `/Applications/World of Warcraft/_retail_/WTF/Account/<KONTO>/SavedVariables/FolioSwap.lua`

Prüfen:
- Gibt es pro Reihe genau eine Auswahl-Node (4 Einträge in `dump`: Kern, Defensiv, Sekundärwert, Capstone)? Wenn stattdessen jede Rune eine eigene Node ist, **stoppen** und mit dem User das Datenformat neu besprechen (Spec-Annahme verletzt).
- Runennamen den Reihen zuordnen und als Tabelle in `docs/presets.md` festhalten (Task 15).

- [ ] **Step 4: Gefundene Probleme beheben**

Typisch: Panel-Position (`panel:SetPoint(...)` in `UI/FolioPanel.lua`) an das echte Fensterlayout anpassen, Edit-Box-Zugriff im Popup. Jede Korrektur als eigener Commit, z. B.:

```bash
git add UI/FolioPanel.lua
git commit -m "fix(ui): Leiste unter dem Foliant-Fenster ausrichten"
```

---

### Task 13: CI

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Workflow schreiben**

`.github/workflows/ci.yml`:
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: leafo/gh-actions-lua@v11
        with:
          luaVersion: "5.1.5"
      - uses: leafo/gh-actions-luarocks@v5
      - name: Werkzeuge installieren
        run: |
          luarocks install busted
          luarocks install luacheck
      - name: Lint
        run: luacheck .
      - name: Tests
        run: busted
```

- [ ] **Step 2: Pushen und Lauf prüfen**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: luacheck und busted auf GitHub Actions"
git push
gh run watch --exit-status "$(gh run list --workflow CI --limit 1 --json databaseId --jq '.[0].databaseId')"
```
Expected: Run endet mit `completed` / `success`

---

### Task 14: Release-Paketierung

**Files:**
- Create: `.pkgmeta`, `.github/workflows/release.yml`, `README.md`, `CHANGELOG.md`, `LICENSE`

- [ ] **Step 1: Packager-Konfiguration**

`.pkgmeta`:
```yaml
package-as: FolioSwap

manual-changelog:
  filename: CHANGELOG.md
  markup-type: markdown

ignore:
  - spec
  - docs
  - scripts
  - README.md
```

`.github/workflows/release.yml`:
```yaml
name: Release

# CalVer-Tags ohne Präfix, z. B. 2026.9.28
on:
  push:
    tags: ["[0-9]*"]

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    env:
      CF_API_KEY: ${{ secrets.CF_API_KEY }}
      GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: BigWigsMods/packager@v2
```

Ohne `CF_API_KEY` bzw. ohne `X-Curse-Project-ID` überspringt der Packager den CurseForge-Upload und erstellt nur das GitHub Release.

- [ ] **Step 2: Doku und Lizenz**

`README.md`:
```markdown
# FolioSwap

Switches your **Omnium Folio** runes (WoW Midnight) automatically when you change specialization.
Save your own setups per spec or use the bundled guide presets.

Stellt die Runen des **Omniumfolianten** beim Spec-Wechsel automatisch um – mit eigenen Profilen
pro Spezialisierung und mitgelieferten Guide-Presets.

## Usage

- Open the Omnium Folio: the bar below it lists the profiles of your current spec.
- `/folio list` – profiles of the current spec
- `/folio save <name>` – save the current Omnium Folio as a profile
- `/folio apply <name>` – apply a profile
- `/folio active <name>` – apply this profile automatically on spec change
- `/folio delete <name>` – delete an own profile
- `/folio dump` / `/folio check` – maintenance of the guide presets

Runes can only be changed out of combat; FolioSwap waits until combat ends.

## Development

`scripts/test.sh` sets up Lua 5.1 locally and runs luacheck and busted.
```

`CHANGELOG.md`:
```markdown
# Changelog

Alle nennenswerten Änderungen an diesem Projekt. Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionen nach CalVer (YYYY.M.D).

## [Unreleased]

### Added
- Automatisches Umstellen des Omniumfolianten beim Spec-Wechsel, im Kampf vorgemerkt bis Kampfende
- Eigene Profile pro Spezialisierung, accountweit gespeichert
- Guide-Presets mit Prüfung gegen den aktuellen Foliant (`/folio check`)
- Profil-Leiste am Foliant-Fenster und Slash-Befehle `/folio`
- Texte auf Deutsch und Englisch
```

`LICENSE`: MIT-Lizenztext mit `Copyright (c) 2026 Madchristian`.

- [ ] **Step 3: Commit**

```bash
git add .pkgmeta .github/workflows/release.yml README.md CHANGELOG.md LICENSE
git commit -m "chore: Release über BigWigs-Packager, README, Changelog und Lizenz"
git push
```

---

### Task 15: Guide-Presets befüllen

Voraussetzung: Dump aus Task 12. Die konkreten Node-/Entry-IDs gibt es erst ingame, deshalb steht die Datentabelle hier nicht im Plan.

**Files:**
- Create: `docs/presets.md`
- Modify: `Core/Presets.lua` (nur `presets.data`)

- [ ] **Step 1: Zuordnungstabelle anlegen**

`docs/presets.md` mit zwei Tabellen:
1. **Runen-IDs:** Reihe → Runenname → nodeID → entryID (aus dem Dump)
2. **Empfehlungen:** specID → Spec-Name → Preset-Name („Guide M+“, „Guide Raid“) → Rune je Reihe → Quelle (URL + Abrufdatum)

Quellen: Method-Klassenguides, Wowhead-Klassenguides, Method „Best Omnium Folio Runes Builds“. Die Sekundärwert-Rune (Reihe 4) folgt der Stat-Priorität der Spec, z. B. aus keystoneloot.io (`/en/classes/<klasse>`).

- [ ] **Step 2: Daten eintragen**

Format in `Core/Presets.lua` (echte IDs aus Tabelle 1):
```lua
presets.data = {
  [62] = { -- Mage – Arcane
    { name = "Guide M+", selections = { [<node Kern>] = <entry>, [<node Defensiv>] = <entry>, [<node Sekundär>] = <entry>, [<node Capstone>] = <entry> } },
  },
}
```

- [ ] **Step 3: Prüfen**

Run: `scripts/test.sh` → alle Tests PASS (u. a. eindeutige Preset-Namen)
Ingame: `/reload`, `/folio check` → „All guide presets match …“

- [ ] **Step 4: Commit**

```bash
git add Core/Presets.lua docs/presets.md
git commit -m "feat(presets): Guide-Empfehlungen für alle Spezialisierungen"
```

---

### Task 16: CurseForge und erstes Release (braucht User-Freigabe)

- [ ] **Step 1: User legt das CurseForge-Projekt an**

User: auf curseforge.com → „Create Project“ → WoW-Addon „FolioSwap“ anlegen, API-Token unter „API Tokens“ erzeugen. Dann:
```bash
gh secret set CF_API_KEY --repo Madchristian/FolioSwap
```

- [ ] **Step 2: Projekt-ID eintragen**

In `FolioSwap.toc` nach `## SavedVariables` einfügen (ID vom User):
```
## X-Curse-Project-ID: <ID vom User>
```

- [ ] **Step 3: Changelog auf die Version setzen**

In `CHANGELOG.md` `## [Unreleased]` durch `## [2026.9.28] – 2026-09-28` ersetzen (bzw. das Datum des Release-Tags).

```bash
git add FolioSwap.toc CHANGELOG.md
git commit -m "chore(release): 2026.9.28"
git push
```

- [ ] **Step 4: Tag nur nach ausdrücklicher Freigabe des Users**

```bash
git tag 2026.9.28
git push origin 2026.9.28
gh run watch --exit-status "$(gh run list --workflow Release --limit 1 --json databaseId --jq '.[0].databaseId')"
```
Expected: GitHub Release `2026.9.28` mit `FolioSwap-2026.9.28.zip`, Datei auf CurseForge sichtbar.
