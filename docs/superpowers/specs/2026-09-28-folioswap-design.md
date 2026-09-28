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
├─ Core/FolioApi.lua        einzige Stelle mit C_Traits
├─ Core/ProfileStore.lua    eigene Profile + aktives Profil (FolioSwapDB)
├─ Core/Presets.lua         schreibgeschützte Guide-Presets
├─ Core/SwapController.lua  Events → Profil auflösen → anwenden
├─ UI/FolioPanel.lua        Leiste am Foliant-Fenster
└─ UI/SlashCommands.lua     /folio
```

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
- `apply(selections)` → Ergebnis `{ applied = {...}, skipped = {...}, reason = ... }`; setzt jede abweichende Auswahl per `SetSelection` und committet einmal am Ende
- `dump()` → alle Nodes/Entries des Baums mit Namen, für die Preset-Pflege

**ProfileStore** – verwaltet `FolioSwapDB`.
```lua
FolioSwapDB = {
  version = 1,
  profiles = { [spec_id] = { [name] = profile } },
  active   = { [spec_id] = name },
  dump     = nil | { ... },   -- letzte Ausgabe von /folio dump
}
```
- `list(spec_id)` → Presets + eigene Profile, Presets zuerst
- `get(spec_id, name)`, `save(spec_id, name, selections)`, `delete(spec_id, name)`
- `set_active(spec_id, name)`, `get_active(spec_id)`
- Presets lassen sich weder überschreiben noch löschen; eigene Profile mit gleichem Namen wie ein Preset werden abgelehnt.
- Ist kein aktives Profil gesetzt, gilt das erste Preset der Spec, falls vorhanden.

**Presets** – reine Datentabelle `[spec_id] = { profile, ... }` plus
`validate(tree_node_ids)` für Tests und `/folio check`.

**SwapController** – verdrahtet Events.
- `PLAYER_SPECIALIZATION_CHANGED` (unit `player`), `PLAYER_ENTERING_WORLD` (Login) → `request_apply()`
- Im Kampf (`InCombatLockdown()`) wird die Anfrage vorgemerkt und bei `PLAYER_REGEN_ENABLED` einmalig ausgeführt.
- Stimmt der aktuelle Zustand schon mit dem Profil überein, passiert nichts und es gibt keine Meldung.

**FolioPanel** – hängt sich per `OnShow` an das Foliant-Fenster
(`ExpansionLandingPage.Overlay.MidnightLandingOverlay.RunesOfPowerFrame`), sobald
es existiert. Elemente: Profil-Dropdown der aktuellen Spec, Buttons „Anwenden“,
„Aktuelles speichern…“, „Löschen“, „Als aktiv setzen“. Eingabe des Namens per
`StaticPopup`.

**SlashCommands** – `/folio` bzw. `/folioswap`:
`list`, `apply <name>`, `save <name>`, `delete <name>`, `active <name>`,
`dump`, `check`, `help`.

## Fehlerbehandlung

| Fall | Verhalten |
|---|---|
| Foliant nicht freigeschaltet | kein Umstellen, einmalige Meldung pro Sitzung |
| Reihe noch gesperrt (`CanPurchaseRank`/`isAvailable` false) | Reihe überspringen, in der Meldung nennen |
| nodeID/entryID nicht im Baum 1186 (Patch) | Eintrag überspringen, Warnung mit Profilnamen |
| `CommitConfig` schlägt fehl | Fehlermeldung, kein Retry-Loop |
| kein Profil für die Spec | nichts tun, keine Meldung |

## Tests

- `busted` mit gemockter `C_Traits`-API (`spec/mocks/c_traits.lua`) für FolioApi, ProfileStore, SwapController (inkl. Kampf-Vormerkung) und Presets-Validierung
- `luacheck` mit `.luacheckrc` (WoW-Globals erlaubt)
- UI wird manuell ingame geprüft

## Release

- Versionierung CalVer `YYYY.M.D`, `## Version: @project-version@` in der `.toc`
- Conventional Commits, `CHANGELOG.md` nach Keep a Changelog
- GitHub Actions:
  - `ci.yml`: luacheck + busted bei Push/PR
  - `release.yml`: bei Tag `v*` BigWigs-Packager (`BigWigsMods/packager`) → GitHub Release + CurseForge-Upload
- `.pkgmeta` schließt `spec/`, `docs/`, `.github/` aus
- CurseForge: Projekt einmalig manuell anlegen, Projekt-ID als `## X-Curse-Project-ID` in die `.toc`, API-Token als Secret `CF_API_KEY`

## Preset-Pflege

1. Ingame `/folio dump` ausführen → Node-/Entry-IDs mit Runennamen werden in `FolioSwapDB.dump` gespeichert
2. Runen-Empfehlungen pro Spec aus den Guides den IDs zuordnen und in `Core/Presets.lua` eintragen
3. `/folio check` bzw. der busted-Test prüft die Tabelle gegen den Baum
