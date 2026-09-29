# Flat-UI-Kandidat: Implementierung und Abnahme

## Umfang

- Originale, assetfreie WoW-Widgets; keine kopierten Quellen, Fonts oder Bilder.
  WeeklyAltTracker/UI.lua und EllesmereUI_FirstInstall.lua wurden ausschließlich lesend
  als Referenz für Prinzipien betrachtet: dunkle Flächen, geringe Abstände,
  zurückhaltender Akzent, klare Hover-/Auswahlzustände. Keine Skin-Abhängigkeit.
- Panel: 520 × 132 logische Pixel, Außenabstand 12, Buttonhöhe 26.
  Kopf: lokalisierter Spec-Name und Client-Icon; darunter Profilauswahl,
  vier Aktionen und die aktive automatische Zuordnung.
- Profilmenü: sechs wiederverwendete Zeilen, Seitenwechsel, gewählte Zeile mit `>` und
  Akzent; aktive automatische Zuordnung zusätzlich mit lokalisiertem `(aktiv)`.
  Keine Blizzard-Button-/Dropdown-Templates. Sichtbare Fenster prüfen ihre Position per
  OnUpdate erneut, damit Verschieben des Folianten und Auflösungswechsel berücksichtigt werden.
  Das Panel bleibt am Folianten, wird aber bei Bedarf in den Viewport verschoben. Das Menü
  öffnet bei Platzmangel nach oben; verbleibender Überlauf wird skalenbewusst begrenzt.
  Auch das Skin-Fenster bleibt innerhalb der Bildschirmgrenzen.
- Skin-Fenster: 360 × 244, auch ohne geöffneten Folianten per `/folio skin` erreichbar.
  Akzent Türkis/Blau/Violett/Bernstein, Hintergrund-Deckkraft 65–100%, Skalierung 80–125%.
  Accountweit in `FolioSwapDB.skin`; normalisierte Defaults: teal / 0.94 / 1.
  Reset verändert nur Skin-Werte. Schritte für Deckkraft/Skalierung: fünf Prozentpunkte.
- Hintergrund RGB 0.055/0.064/0.078; Button RGB 0.105/0.12/0.145.
  Aktiver/Hover-Button nutzt den abgedunkelten Akzent; Text ist weißgrau, deaktiviert grau.
  Font: Blizzard GameFontHighlightSmall. Kein fremdes Font-Paket.
- Der bestehende Speichern-Namensdialog bleibt absichtlich ein Blizzard-StaticPopup.
  Speicher-, Lösch-, Anwenden- und Automatikaktionen nutzen unverändert Core/Actions.lua.

## Spezialisierungen

Die Speicherung pro echter Spec-ID und der automatische Wechsel existierten bereits.
Neu sind sichtbare Spec-Identität, aktive automatische Zuordnung, verständliche
Zuordnungsaktion und das Zurücksetzen der UI-Auswahl beim Spec-Wechsel.
Druiden bleiben vier getrennte IDs: 102, 103, 104, 105; keine Zusammenfassung nach Rolle.
`GetSpecializationInfo` liefert Name an Position 2 und Icon an Position 4; geprüft gegen
Blizzards generierte SpecializationInfoDocumentation.lua. Der vorhandene globale
API-Zugang bleibt erhalten (Blizzard_DeprecatedSpecialization ordnet ihn der gleichnamigen
C_SpecializationInfo-Funktion zu); dieses UI-Änderungspaket migriert den Core-API-Zugang nicht.

## Nachweis und reproduzierbare Gates

Echter nativer PUC Lua 5.1.5, nicht der systemweite Lua-5.4-Interpreter.
Die lokale, Git-ignorierte `.lua/`-Toolchain enthält busted und luacheck.
Vom Repository-Wurzelverzeichnis in Git Bash:

```sh
.lua/bin/lua scripts/verify.lua lint
.lua/bin/lua scripts/verify.lua test
.lua/bin/lua scripts/verify.lua parse
# optional nur das UI-Runtime-Harness:
.lua/bin/lua scripts/verify.lua test spec/folio_panel_spec.lua
```

Der Runner setzt nur projektlokale Modulpfade, prüft `_VERSION` und ruft die echten
busted-/luacheck-Runner auf. `parse` kompiliert alle TOC-Dateien ohne Ausführung.
Der bestehende Linux-/WSL-CI-Weg `scripts/test.sh` bleibt unverändert.

TDD: Neue Verhaltensslices wurden zunächst mit realem Fehlschlag ausgeführt:
fehlende Skin-Normalisierung, fehlende Flat-Widgets, vorhandene Blizzard-Templates,
fehlendes wiederverwendetes Profilmenü, fehlende Skin-Bedienung, fehlende Spec-Anzeige,
falscher Platzhalter bei vorhandenen Profilen und offenes Profilmenü über Skin-Einstellungen.
Danach jeweils Implementierung und grüner Lauf. Zusätzliche Erhaltungstests prüfen
vier echte Spec-IDs mit unterschiedlichen Runen über den bestehenden Controller.

Runtime-Harness: Templatefreiheit, Hover/Auswahl/Disabled, ein Click-Edge,
alle Profilaktionen einschließlich ursprünglichem Popup-Callback, Menüseiten und Schrumpfen,
Skin-Bedienung/Reset/Persistenz, TOC-Bootstrap/erneutes Öffnen, beide Locales,
Geometrie/Skalengrenzen und konstante Frame-Anzahl. Diese Mocks sind kein WoW-Renderer.

## In-Game-Abnahme

Am 2026-09-29 wurde die vom Benutzer gemeldete erfolgreiche funktionale und visuelle
Abnahme des damals installierten Kandidaten vor der asynchronen Commit-Korrektur dokumentiert.
Die Bestätigung umfasst auch die
korrigierte Ebenenreihenfolge des Skin-Fensters. Screenshots wurden ausdrücklich weder
angefordert noch bereitgestellt; sie sind kein verbleibendes Abnahmekriterium.

Dies ist eine Benutzerbestätigung, keine durch den automatisierten Runner beobachtete
Client-Prüfung. Eine vollständige Einzelbestätigung jeder Kombination aus Sprache,
Auflösung, Skalierung und Spezialisierung liegt nicht vor. Die Mock-Tests prüfen keine
realen Glyphenbreiten oder WoW-Rendering-Ergebnisse. Guide-Presets sind nicht enthalten.
Der Blizzard-Speicherdialog bleibt eine bewusste visuelle Ausnahme.

Die lokale Release-Vorbereitung verändert weder die WoW-Installation noch SavedVariables.
Die spätere asynchrone Commit-Korrektur ist damit noch nicht im Spiel abgenommen.
Offen bleibt ein gezielter In-Game-Test mit dem korrigierten Stand: manuelles Anwenden,
Erfolgsmeldung erst nach bestätigter Übernahme, schnelle Spec-/manuelle Wechsel und
Fortsetzung nach Kampfende (siehe docs/trait-commit-contract.md). Screenshots sind dafür
nicht erforderlich.
Vor einer Veröffentlichung bleiben drei unabhängige Reviews des finalen Kandidaten
sowie die gesonderte Freigabe für Commit, Push und Release erforderlich.
