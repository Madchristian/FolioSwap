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

FolioSwap never auto-buys runes for rows you haven't unlocked yet; pick those in the Folio yourself.
If the game is busy or the Folio hasn't loaded yet at login, FolioSwap retries for a few seconds.

## Development

`scripts/test.sh` sets up Lua 5.1 locally and runs luacheck and busted.
