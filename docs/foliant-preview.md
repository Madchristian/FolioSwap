# Foliant: Implementierung und Abnahme für 2026.9.30

Dieser Stand implementiert die freigegebene **Variante A / Foliant**, nicht Variante B.
Der Kandidat `9166002f4bc54c4c0e749c609120da529d06e65eefa499ea7f0a3ee9138b5643`
erhielt drei unabhängige READY-Reviews und wurde nach Freigabe installiert.
Alle 19 installierten Dateien wurden bytegenau gegen den geprüften Snapshot verglichen;
SavedVariables blieben unverändert. Am 2026-09-30 bestätigte der Benutzer:
„funktioniert alles wie erwartet, kannst ein neuen release starten“.
Dies ist eine Benutzerabnahme, keine vom Agenten beobachtete Client-Prüfung.
Screenshots wurden nicht bereitgestellt oder geprüft. Die Release-Vorbereitung ändert
nur Dokumentation und den Packaging-Versionstest; der abgenommene Addon-Code bleibt unverändert.

## Gestaltung und Bedienung

- Das vorhandene 520 × 132 Panel bleibt erhalten: Spec-Kopf, breite Profilauswahl,
  Anwenden / Speichern / Löschen / Für diese Spec verwenden, Automatikstatus.
  Buttonhöhe 26, Außenabstand 12, sechs wiederverwendete Menüzeilen und Paging unverändert.
- **Foliant:** warmer Verlauf von `#312720` oben zu `#1A181B` unten;
  dünne violette Kante `#756084`, dunkle Innenlinie `#211B26`, dezente obere Glanzlinie.
  Text `#E9DECB`, Gold `#D5B87E`, Hover `#493651` mit hellerer violetter Kante.
  Die vier Rahmenlinien liegen innerhalb der Frame-Bounds, nicht außerhalb.
- Gold kennzeichnet die Primäraktion Anwenden, die gewählte Menüzeile und eine
  Profilauswahl, die tatsächlich der automatischen Zuordnung entspricht. Eine andere
  Auswahl macht die Zuordnung **nicht** aktiv. Bestehende Textmarker `>` und `(aktiv)`
  bleiben erhalten; Gold ist nie der einzige Zustandsnachweis. Disabled übersteuert
  Gold und Hover. Der Automatikstatus bleibt als eigener Text sichtbar.
- **Flat:** ursprüngliche dunkle Flächen und Akzent-Unterstreichung; Türkis, Blau,
  Violett oder Bernstein. Foliant-Rahmen, Innenlinie und Glanz werden ausgeblendet,
  der Verlauf wird beim Umschalten explizit neutralisiert.
- Dock-Abstand zum unteren Anker des Folianten: Foliant 4 statt Flat 16 lokale
  Panel-Einheiten. Bestehendes skalenbewusstes Screen-Clamping hat weiter Vorrang.
  Reicht der Platz unter der Profilauswahl nicht, öffnet das Menü nach oben.
- Die Skin-Einstellungen stehen unter **Optionen → AddOns → FolioSwap**, auch ohne
  geladenes Foliantfenster. Skin-Button und `/folio skin` öffnen dieselbe Kategorie.
  Darstellung **Foliant / Flat** ist direkt erreichbar; der aktive Stil hat einen `>`-Marker.
  Die vier gespeicherten Akzentfarben bleiben sichtbar, sind aber bei Foliant deaktiviert
  und mit „Akzent (nur Flat)“ erklärt. Wechsel zurück zu Flat stellt den Akzent wieder her.
  Hintergrund-Deckkraft 65–100 %, Skalierung 80–125 %, Schritte fünf Prozentpunkte.
  Änderungen wirken sofort. Skalierung und Hintergrund-Deckkraft gelten nur für das
  Addon-Panel/Profilmenü, nicht für Blizzards Einstellungsfenster.
- Die Kategorie wird nach der SavedVariables-Initialisierung einmalig registriert.
  Blizzard besitzt Parent, Layout, Ebene und Schließen der Canvas-Seite; kein separates
  Skin-Fenster, eigener X-Button oder eigener ESC-Eintrag. Das Profilmenü schließt beim Öffnen.

## Persistenz und Migration

`FolioSwapDB.skin` enthält `theme`, `accent`, `opacity`, `scale`.
Gültige Stile sind exakt `foliant` und `flat`; fehlende oder ungültige Werte werden
zu `foliant`. Bestehende gültige Akzent-, Deckkraft- und Skalierungswerte bleiben
unverändert – auch die frühere Deckkraft 0.94 wird **nicht** auf 0.98 angehoben.
Neue bzw. zurückgesetzte Skin-Daten erhalten `foliant / teal / 0.98 / 1`.
Grenzen und Validierung der bisherigen Parameter bleiben erhalten.

Es gibt keinen DB-Reset und keine Versionsmigration der Profile. Bootstrap registriert die Einstellungsseite.
Profilinhalte, automatische Zuordnungen und asynchrone Commit-/Combat-/Retry-Logik
bleiben unverändert. Reset betrifft ausschließlich den Skin.

## Originalität und Abweichungen zur Browserreferenz

Nur selbst gezeichnete WoW-ColorTextures, native FontStrings und vorhandenes Spec-Icon;
keine neuen Bilddateien, Fonts, Addon-Abhängigkeiten oder kopierte Blizzard-Ornamente.
Der private Screenshot und das HTML mit eingebettetem Screenshot bleiben außerhalb
des Repositorys und gehören niemals ins Addon-Paket.

Die HTML-Referenz benutzt einen diagonalen CSS-Verlauf, Systemfont und Screenshotpixel.
Die Umsetzung verwendet einen vertikalen nativen Verlauf, `GameFontHighlightSmall`
und die bestehenden logischen UI-Maße. Sie ist kein pixelidentischer Browsernachbau.
Der bestehende Blizzard-StaticPopup zum Speichern bleibt bewusst unverändert; die
zusätzlichen Browser-Tooltips/Fokusdarstellungen sind kein neu implementiertes Widgetsystem.

Neue API-Verwendung wurde gegen Blizzard-Quellen für **12.1.0** geprüft:
- [TextureBase:SetGradient](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua)
  nimmt Orientierung sowie zwei ColorMixin-Farben einschließlich Alpha entgegen.
- [CreateColor](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_SharedXMLBase/Color.lua)
  erzeugt diese Farben. Texture-Gradienten werden im Mock nicht als FontString-Methode angeboten.

## Ausgeführte Gates

```sh
.lua/bin/lua scripts/verify.lua test
.lua/bin/lua scripts/verify.lua lint
.lua/bin/lua scripts/verify.lua parse
python scripts/test_package_release.py
```

Ergebnis nach Settings-Integration: **159 Tests grün**, luacheck **0 Warnungen / 0 Fehler**
in 36 Dateien, Lua-5.1-Parser **16 TOC-Dateien**. Der Settings-Test schlug vor der
Implementierung wegen der fehlenden Kategorie fehl und wurde danach grün.
Die Feature-Slices wurden vor ihrer Implementierung rot ausgeführt: fehlender persistierter
Stil, fehlender nativer Verlauf, fehlende Stilbedienung und alter Dock-Abstand. Danach grün.

Regressionen prüfen Migration/ungültige Stile/Reset/TOC-Neuladen, reale Flächen- und
Rahmenfarben bei Hover/Selected/Primary/Disabled, den Wechsel zurück zu Flat, übersetzte
Stilbedienung und unveränderte Profile/Zuordnungen. Geometrieprüfungen decken beide Stile,
enUS/deDE, UIParent-Skalen 0.64/1 und Panel-Skalen 0.8/1/1.25 ab, einschließlich aller
Skin-Schaltflächen ohne gegenseitige Überlappung in einem 1024 × 768 Viewport.
Bestehende Tests für Profilaktionen, Menüseiten, vier Druidenspecs und asynchrone Commits
laufen unverändert mit. Das ist ein gemockter Lauf unter echtem Lua 5.1, kein WoW-Renderer.

## Umfang und Grenzen der In-Game-Abnahme

Die finale Benutzerbestätigung gilt für den oben genannten installierten Kandidaten.
Für jede Kombination aus Sprache, Auflösung, Skalierung und Spec liegt keine separate
Einzelbestätigung vor. Die folgende Checkliste dokumentiert die relevanten Prüfpunkte,
nicht automatisch beobachtete oder einzeln bestätigte Testergebnisse.

- Foliant an der tatsächlichen unteren Artwork-Kante: enger, ohne Übermalen/Abschneiden;
  kleine Auflösung, bewegter Foliant und Skin-Skalen 80/100/125 % prüfen.
- Schrift, lange deutsche Profilnamen und Labels sowie dünne Linien bei effektiver
  UI-Skalierung ansehen. Mock-Bounds beweisen weder Glyphenbreite noch Texture-Rasterung.
- Foliant/Flat mehrfach wechseln, Akzentwerte wiederfinden, Deckkraft/Textkontrast,
  Reload-Persistenz und Skin-Reset ohne Profilverlust bestätigen.
- Kategorie direkt nach Login ohne vorheriges Öffnen des Folianten auswählen; Skin-Button
  und `/folio skin` müssen dieselbe eingebettete Seite öffnen. Kategorie wechseln,
  Optionen schließen/erneut öffnen, ESC und Skalen 80/125 % ohne Seitenvergrößerung testen.
- Sechs Menüzeilen/Paging, Aufklappen nach oben/unten, Hover/Disabled und Speichern-Popup testen.
- Auswahl gegenüber automatischer Zuordnung und Anwenden klar unterscheiden. Manueller
  Wechsel, vier Druidenspecs, Commit-Bestätigung und Fortsetzung nach Kampfende bleiben
  Teil der funktionalen Abnahme. Die frühere Flat-Abnahme gilt nicht für diesen neuen Skin.
