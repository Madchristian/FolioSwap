# FolioSwap – Projektkontext für Claude Code

WoW-Addon (Retail 12.1.0 Midnight, Lua 5.1): stellt die Runen des Omniumfolianten
(„Omnium Folio“, intern „Runes of Power“, `C_Traits` System 48 / Tree 1186) beim
Spec-Wechsel und Login automatisch auf das aktive Profil der Spec um. Eigene Profile
pro Spec (accountweit, `FolioSwapDB`) plus mitgelieferte Guide-Presets.

- Spec (maßgeblich, auf dem Stand der Umsetzung): `docs/superpowers/specs/2026-09-28-folioswap-design.md`
- Ursprünglicher Plan: `docs/superpowers/plans/2026-09-28-folioswap.md` – Task 1–11, 13, 14 sind
  umgesetzt; während der Umsetzung gab es Review-Änderungen, die **nur** in der Spec und den Commits
  stehen, nicht im Plan. Bei Widerspruch gilt die Spec bzw. der Code.
- Preset-Pflege: `docs/presets.md`

## Befehle

| Zweck | Befehl |
|---|---|
| Lint + Tests (legt beim ersten Lauf Lua 5.1 in `.lua/` an) | `scripts/test.sh [spec/datei_spec.lua]` |
| Addon ins Spiel verlinken, Windows | `powershell -ExecutionPolicy Bypass -File scripts\link-addon.ps1` |
| Addon ins Spiel verlinken, macOS | `scripts/link-addon.sh` |

`scripts/test.sh` braucht eine POSIX-Shell, einen C-Compiler und `uv` (für `uvx hererocks`).
Unter Windows daher in **WSL** ausführen (siehe README „Development“). CI (GitHub Actions) führt
luacheck + busted bei jedem PR aus und ist die verbindliche Prüfung.

## Architektur (Kurzfassung)

Jede Datei beginnt mit `local _, ns = ...`; Module hängen an `ns`. `FolioSwap.toc` ist Lade-
und Testreihenfolge (`spec/helpers/wow_env.lua` liest die `.toc`, überspringt `UI/FolioPanel.lua`
und `Core/Bootstrap.lua`).

- `Core/FolioApi.lua` – einzige Stelle mit `C_Traits`. Vertrag von `apply`: siehe Kommentar dort.
- `Core/ProfileStore.lua` – `FolioSwapDB`, sanitize, Preset-Kollisionen → „Name (2)“.
- `Core/Presets.lua` – Guide-Daten (`presets.data`, **noch leer**).
- `Core/Actions.lua` – gemeinsamer Pfad für Slash, Panel und Automatik.
- `Core/Reporter.lua` – einzige Chat-Ausgabe; Drosselung pro Sitzung für die Automatik.
- `Core/SwapController.lua` – Events, Kampf-Vormerkung, Timer-Retry (2 s, 1+5 Versuche).
- `UI/SlashCommands.lua`, `UI/FolioPanel.lua`, `Core/Bootstrap.lua` – dünner Frame-Code.

## Bewusste Entscheidungen (nicht zurückdrehen ohne Grund)

- Unbelegte Reihen werden **nie** automatisch gekauft (Skip `unpurchased`) – der Erstkauf kostet Währung.
- Vor jedem Umstellen `IsReadyForCommit()`/`CanEditConfig()`; bei Commit-Fehler `RollbackConfig`.
- Retry per `C_Timer` statt auf `TRAIT_CONFIG_UPDATED` zu warten (Events kamen im Review als unzuverlässig heraus;
  beim Login ist die Foliant-Config evtl. noch nicht geladen).
- Automatik bleibt still bei „schon aktiv“, `busy`, `unavailable` (erst nach ausgeschöpftem Budget eine Meldung);
  manuelle Befehle melden immer.
- Rune-Identität `nodeID → entryID`; Presets werden per `/folio check` gegen den Baum geprüft.

## Konventionen

- Lua-Bezeichner `snake_case`, Kommentare Deutsch, SOLID/DRY.
- TDD: erst Test in `spec/`, dann Code; `scripts/test.sh` muss grün sein (luacheck 0/0).
- Conventional Commits, CalVer `YYYY.M.D` für Releases (Tags **ohne** `v`, z. B. `2026.9.28`),
  `CHANGELOG.md` nach Keep a Changelog.
- Arbeit auf Feature-Branches, Merge über PR.

## Stand (2026-09-29)

- Branch `feature/v1`, Draft-PR #1 – 119 Tests grün, CI grün. `main` enthält nur Spec + Plan.

## Nächste Schritte

1. **Ingame-Test (Task 12):** Addon verlinken, einloggen, `/folio dump` + `/reload`; Checkliste im Plan, Task 12.
   Dump auswerten aus `WTF/Account/<KONTO>/SavedVariables/FolioSwap.lua` (`FolioSwapDB.dump`).
   Prüfen: genau eine Auswahl-Node pro Reihe? Sonst Datenformat neu besprechen. Unsichtbare Nodes → ggf.
   `isVisible`-Filter in `choice_nodes`. Panel-Position (`SetPoint`-Offset) ggf. anpassen.
2. **Presets befüllen (Task 15):** `docs/presets.md` ausfüllen, `presets.data` in `Core/Presets.lua` eintragen,
   `/folio check` ingame.
3. **Release (Task 16):** CurseForge-Projekt anlegen (manuell), `## X-Curse-Project-ID` in die `.toc`,
   Secret `CF_API_KEY` setzen, PR mergen, Tag `YYYY.M.D` pushen – nur nach ausdrücklicher Freigabe.
