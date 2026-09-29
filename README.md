# FolioSwap

Switches your **Omnium Folio** runes (WoW Midnight) automatically when you change specialization.
Save your own setups per spec; guide presets are added as soon as the rune IDs are confirmed in-game.

Stellt die Runen des **Omniumfolianten** beim Spec-Wechsel automatisch um – eigene Profile pro
Spezialisierung speichern; Guide-Presets kommen dazu, sobald die Runen-IDs im Spiel bestätigt sind.

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

```sh
git clone https://github.com/Madchristian/FolioSwap.git
cd FolioSwap
git switch feature/v1   # until PR #1 is merged
```

**Tests** – `scripts/test.sh` sets up Lua 5.1 locally (`.lua/`, via `uvx hererocks`) and runs luacheck and busted.

- macOS/Linux: needs `uv` and a C compiler (Xcode CLT / build-essential).
- Windows: run it inside WSL (Ubuntu):
  ```sh
  sudo apt install -y build-essential curl git
  curl -LsSf https://astral.sh/uv/install.sh | sh   # then open a new shell
  cd /mnt/c/<path>/FolioSwap && scripts/test.sh
  ```
  GitHub Actions runs the same checks on every pull request.

**Run in game** – link the repo into your AddOns folder, then `/reload`:

- Windows (PowerShell, no admin needed): `powershell -ExecutionPolicy Bypass -File scripts\link-addon.ps1`
  (finds WoW via the registry; override with `-RetailPath "D:\World of Warcraft\_retail_"`)
- macOS: `scripts/link-addon.sh`

Project context for Claude Code: see `CLAUDE.md`.
