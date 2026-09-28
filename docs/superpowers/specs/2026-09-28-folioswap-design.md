# FolioSwap – Design

Stand: 2026-09-28 · WoW Retail 12.1.0 (Midnight)

## Ziel

FolioSwap stellt die Runen des Omniumfolianten (engl. *Omnium Folio*, intern
„Runes of Power“) automatisch auf das passende Setup um, sobald der Spieler die
Spezialisierung wechselt. Spieler können eigene Setups pro Spec speichern und
zusätzlich mitgelieferte Guide-Presets („Best Settings“) nutzen.

Veröffentlichung: öffentliches GitHub-Repo `Madchristian/FolioSwap` und
CurseForge-Projekt „FolioSwap“.

## Nicht-Ziele (v1)

- Kein automatisches Umschalten nach Content-Typ (Raid/M+/Welt)
- Kein Scraping von Guide-Seiten; keystoneloot.io liefert keine Foliant-Daten
- Kein Import/Export per String, kein Minimap-Button, kein eigenes Fenster

## Technische Grundlage

Laut Blizzard-UI-Quellcode (`Blizzard_MidnightLandingPage.lua`, Build 12.1.0
69933) ist der Foliant ein generischer Trait-Baum:

| Konstante | Wert |
|---|---|
| `RUNES_OF_POWER_SYSTEM_ID` | `48` |
| `RUNES_OF_POWER_TREE_ID` | `1186` |

Genutzte API: `C_Traits.GetConfigIDBySystemID`, `C_Traits.GetTreeNodes`,
`C_Traits.GetNodeInfo`, `C_Traits.GetEntryInfo`, `C_Traits.SetSelection`,
`C_Traits.CommitConfig`. Umstellen ist kostenlos, aber nur außerhalb des Kampfes
möglich.

Aufbau: 5 Reihen (Kern, Defensiv, Rune of Lingering ohne Auswahl, Sekundärwert,
Capstone). Pro Reihe genau eine Auswahl-Node.

## Entscheidungen

| Frage | Entscheidung |
|---|---|
| Datenquelle Best Settings | Kuratierte Lua-Datentabelle im Addon, gepflegt aus Method, Wowhead und den Klassenguides, ausgeliefert mit jedem Release |
| Auslösung | Automatisch beim Spec-Wechsel und beim Login, mit Chat-Hinweis; im Kampf vorgemerkt bis Kampfende |
| Profile | Pro Spec eine Liste aus Presets (schreibgeschützt) und eigenen Profilen, genau eines davon aktiv; Speicherung accountweit |
| Oberfläche | Kleine Leiste am Foliant-Fenster, dazu `/folio` |
| Sprache | deDE und enUS |
| Rune-Identität | `nodeID → entryID` (Variante 1), beim Laden gegen Baum 1186 geprüft |

## Architektur

```
FolioSwap/
├─ FolioSwap.toc            Interface 120100; SavedVariables: FolioSwapDB
├─ Locales/enUS.lua         Basis-Texte
├─ Locales/deDE.lua         deutsche Überschreibungen
├─ Core/Util.lua            sorted_keys, contains, copy, trim
├─ Core/FolioApi.lua        einzige Stelle mit C_Traits
├─ Core/Presets.lua         schreibgeschützte Guide-Presets
├─ Core/ProfileStore.lua    eigene Profile + aktives Profil (FolioSwapDB)
├─ Core/Player.lua          aktuelle Spec-ID
├─ Core/Reporter.lua        Chat-Meldungen, Drosselung pro Sitzung
├─ Core/Actions.lua         gemeinsamer Pfad für Slash-Befehle, Panel und Automatik
├─ Core/SwapController.lua  Events → Actions.apply_active()
├─ UI/FolioPanel.lua        Leiste am Foliant-Fenster
├─ UI/SlashCommands.lua     /folio
└─ Core/Bootstrap.lua       ADDON_LOADED, Event-Registrierung
```

Die Datei-Reihenfolge in `FolioSwap.toc` ist zugleich die Ladereihenfolge im Spiel und die
Testlade-Reihenfolge (`spec/helpers/wow_env.lua` liest die `.toc` ein).

Lua-Bezeichner in `snake_case`. Module hängen am Addon-Namespace (`local _, ns = ...`),
keine Globals außer `FolioSwapDB` und den Slash-Command-Variablen.

### Datenformat Profil

Presets und eigene Profile teilen dasselbe Format und laufen durch denselben
Codepfad:

```lua
{
  name = "Method M+",          -- eindeutig pro Spec
  source = "preset" | "user",
  selections = {               -- nodeID → entryID
    [101234] = 204567,
    [101235] = 204571,
  },
}
```

### Module

**FolioApi** – kapselt die Blizzard-API, sonst nichts.
- `is_available()` → `true`, wenn eine configID für System 48 existiert
- `read_current()` → `selections` des aktuellen Zustands (nur Auswahl-Nodes mit mehr als einem Eintrag)
- `catalog()` → `[node_id] = { entryID, ... }` aller Auswahl-Nodes, Grundlage für `/folio check`
- `apply(selections)` → prüft vorab `IsReadyForCommit()`/`CanEditConfig()`, setzt jede abweichende
  Auswahl per `SetSelection` und committet einmal am Ende. Ergebnisvertrag:
  `{ applied = {node_id, ...}, skipped = {{node_id, reason, name?}, ...},
  reason = nil | "unavailable" | "busy" | "cannot_edit" | "commit_failed" }`. Skip-Gründe:
  `unknown | locked | unpurchased | rejected`, mit dem Namen der gewünschten Rune außer bei
  `unknown`. Schlägt `CommitConfig` fehl, rollt `apply` zurück – `applied` bleibt dann leer. Ein
  Tausch zwischen bereits belegten Einträgen ist auch bei `isAvailable = false` erlaubt; der
  Erstkauf eines unbelegten Nodes wird nie ungefragt ausgelöst.
- `dump()` → alle Nodes/Entries des Baums mit Namen, für die Preset-Pflege

**ProfileStore** – verwaltet `FolioSwapDB`, die Grenze zu den SavedVariables.
```lua
FolioSwapDB = {
  version = 1,
  profiles = { [spec_id] = { [name] = profile } },
  active   = { [spec_id] = name },
  dump     = nil | { ... },   -- letzte Ausgabe von /folio dump
}
```
- `init(db)` → verwirft grob kaputte Daten (falscher Typ der Wurzel, kaputte Profile, nicht-string
  Schlüssel) statt daran zu crashen (`sanitize`)
- `list(spec_id)` → Presets + eigene Profile, Presets zuerst
- `get(spec_id, name)`, `save(spec_id, name, selections)`, `delete(spec_id, name)`,
  `set_active(spec_id, name)` trimmen `name` jeweils per `util.trim` – einheitlich an der Grenze zu
  den Daten
- `active_name(spec_id)` → gesetztes aktives Profil, sonst das erste Preset der Spec, falls vorhanden
- `get_active(spec_id)` → Profil zu `active_name(spec_id)`
- Presets lassen sich weder überschreiben noch löschen; eigene Profile mit gleichem Namen wie ein Preset werden abgelehnt.
- Liefert ein späteres Guide-Update ein Preset unter einem schon vergebenen eigenen Profilnamen aus,
  wird das eigene Profil beim nächsten `init` auf `"Name (2)"` (nächste freie Nummer) umbenannt;
  zeigte das aktive Profil auf den alten Namen, wandert es mit um

**Presets** – reine Datentabelle `[spec_id] = { profile, ... }` plus
`validate(tree_node_ids)` für Tests und `/folio check`.

**SwapController** – verdrahtet Events, ruft dafür `Actions.apply_active()` auf.
- `PLAYER_SPECIALIZATION_CHANGED` (unit `player`) sowie `PLAYER_ENTERING_WORLD` nur bei
  `isInitialLogin` oder `isReloadingUi` → `request_apply()`, jeweils mit frischem Retry-Budget
  (Zähler auf 0)
- Bei `busy`/`unavailable` wiederholt ein `C_Timer.After`-Timer alle 2 Sekunden (1 Sofortversuch +
  5 Wiederholungen); nach Ausschöpfen genau eine Meldung, dann Aufgeben. `PLAYER_REGEN_ENABLED`
  (Fortsetzung eines laufenden Versuchs nach dem Kampf) setzt das Budget nicht zurück
- Im Kampf (`InCombatLockdown()`) wird nur vorgemerkt, wenn `Actions.needs_apply()` tatsächlich
  eine Abweichung findet (Spec + aktives Profil vorhanden und `read_current()` weicht ab oder ist
  unbekannt); sonst bleibt es still. Vorgemerktes wird bei `PLAYER_REGEN_ENABLED` einmalig nachgeholt
- Stimmt der aktuelle Zustand schon mit dem Profil überein, passiert nichts und es gibt keine Meldung.

**FolioPanel** – hängt sich per `hooksecurefunc(RunesOfPowerMixin, "OnShow", ...)` und zusätzlich
per `HookScript("OnShow", ...)` am bereits vorhandenen
`ExpansionLandingPage.Overlay.MidnightLandingOverlay.RunesOfPowerFrame` an; `try_attach()` wird bei
jedem `ADDON_LOADED` erneut versucht, solange das Blizzard-Addon (und damit `RunesOfPowerMixin`)
noch fehlt. Elemente: Profil-Dropdown der aktuellen Spec, Buttons „Anwenden“, „Aktuelles
speichern…“, „Löschen“, „Aktivieren“. Eingabe des Namens per `StaticPopup`. Aktualisiert sich bei
Spec-Wechsel (`Bootstrap` ruft `refresh()`) und nach jeder Aktion, weil `Actions` selbst
`folio_panel.refresh()` aufruft.

**SlashCommands** – `/folio` bzw. `/folioswap`:
`list`, `apply <name>`, `save <name>`, `delete <name>`, `active <name>`,
`dump`, `check`, `help`.

## Fehlerbehandlung

| Fall | Verhalten |
|---|---|
| `busy` (Spiel speichert noch) | manuell sofort gemeldet; Automatik wiederholt per Timer und meldet erst nach Ausschöpfen aller Retries, dann einmal pro Sitzung |
| `unavailable` (Foliant nicht freigeschaltet) | manuell immer gemeldet; Automatik genauso per Timer-Retry, danach ebenfalls einmal pro Sitzung |
| `cannot_edit` (Config gerade nicht bearbeitbar) | sofort gemeldet, kein Retry |
| Reihe noch gesperrt (`unpurchased`, `isAvailable` false ohne bestehende Auswahl) | Reihe überspringen, mit Runennamen in der Meldung nennen |
| vom Spiel abgelehnt (`rejected`) | Eintrag überspringen, mit Runennamen in der Meldung nennen |
| nodeID/entryID nicht im Baum 1186 (`unknown`, Patch) | Eintrag überspringen, ohne Runennamen (unbekannt) |
| Skips in der Automatik | dieselbe Kombination aus Profil + Node/Grund wird nur einmal pro Sitzung gemeldet; manuell jedes Mal |
| `CommitConfig` schlägt fehl (`commit_failed`) | Rollback, Fehlermeldung, `applied` bleibt leer |
| kein Profil für die Spec | nichts tun, keine Meldung |

## Tests

- `busted` mit gemockter `C_Traits`-API (`spec/helpers/c_traits_mock.lua`) und einer Testumgebung,
  die die echten Addon-Dateien in der Reihenfolge der `.toc` lädt (`spec/helpers/wow_env.lua`), für
  FolioApi, ProfileStore, SwapController (inkl. Kampf-Vormerkung) und Presets-Validierung
- `luacheck` mit `.luacheckrc` (WoW-Globals erlaubt)
- `scripts/test.sh` richtet Lua 5.1 samt `busted`/`luacheck` projektlokal per `hererocks` ein
  (einmalig in `.lua/`) und führt danach Lint und Tests aus
- UI wird manuell ingame geprüft

## Release

- Versionierung CalVer `YYYY.M.D`, `## Version: @project-version@` in der `.toc`
- Conventional Commits, `CHANGELOG.md` nach Keep a Changelog
- GitHub Actions:
  - `ci.yml`: luacheck + busted bei Push/PR
  - `release.yml`: Tag-Trigger `[0-9]*` (CalVer ohne Präfix, z. B. `2026.9.28`) → BigWigs-Packager
    (`BigWigsMods/packager`) → GitHub Release + CurseForge-Upload
- `.pkgmeta` schließt `spec`, `docs`, `scripts`, `README.md` aus; Dotfiles (`.luacheckrc`, `.busted`, …) schließt der Packager selbst aus
- CurseForge: Projekt einmalig manuell anlegen, Projekt-ID als `## X-Curse-Project-ID` in die `.toc`, API-Token als Secret `CF_API_KEY`

## Preset-Pflege

1. Ingame `/folio dump` ausführen → Node-/Entry-IDs mit Runennamen werden in `FolioSwapDB.dump` gespeichert
2. Runen-Empfehlungen pro Spec aus den Guides den IDs zuordnen und in `Core/Presets.lua` eintragen
3. `/folio check` bzw. der busted-Test prüft die Tabelle gegen den Baum
