# FolioSwap

FolioSwap remembers your Omnium Folio rune setups and applies the profile assigned to your specialization when you switch specs or log in.

Open the Omnium Folio to manage your profiles in a compact panel below the game's window. Save your current setup, select a profile to apply now, or assign one for automatic switching.

## Features

- Save multiple rune profiles per specialization, stored account-wide.
- Assign an automatic profile to each spec, including all four Druid specializations.
- Apply profiles manually without changing your automatic assignment.
- Keep profile selection separate from applying runes: browsing the list does not change your setup.
- Customize the panel's accent color, background opacity and scale.
- Use the interface in English or German, selected automatically from your game language.

If a change is pending during combat, FolioSwap waits until combat ends. It also retries briefly when the game is busy or the Folio has not finished loading.

FolioSwap never purchases runes in rows you have not unlocked. Make those initial choices yourself in the Omnium Folio.

## Getting started

1. Open the Omnium Folio and choose your runes.
2. Save the current setup as a named profile in the FolioSwap panel.
3. Choose **Use for this spec** to assign it to your current specialization.
4. Repeat for your other specs. FolioSwap will apply their assigned profiles when you switch.

Use **Apply** whenever you want to load a profile immediately. Choosing a profile from the list or assigning it to a spec does not apply it immediately.

## Commands

- `/folio list`: list profiles for your current specialization.
- `/folio save <name>`: save your current rune setup.
- `/folio apply <name>`: apply a saved profile.
- `/folio active <name>`: assign the automatic profile for your current spec.
- `/folio delete <name>`: delete one of your own profiles.
- `/folio skin`: customize the panel's appearance.

## Requirements and limitations

Requires World of Warcraft Retail with the Omnium Folio available to your character. Built-in guide presets are not included yet; create your own profiles from your current rune selections.

## Support and license

Report bugs or request features on [GitHub](https://github.com/Madchristian/FolioSwap/issues). Please include what you were doing and any Lua error message.

All Rights Reserved. Private, non-commercial use, personal backups and sharing an unchanged original archive within a private guild or gaming community are permitted. Modifications, public reuploads, mirrors, addon bundles and commercial use require prior written permission. See [LICENSE](LICENSE) for full terms. MIT rights already granted for earlier versions remain in effect.

FolioSwap is an independent fan project and is not affiliated with Blizzard Entertainment.

See [CHANGELOG.md](CHANGELOG.md) for release notes and [UI acceptance](docs/ui-acceptance.md) for the reported in-game acceptance and automated test scope.

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

For an existing native Windows Lua 5.1 toolchain, run from Git Bash:

```sh
.lua/bin/lua scripts/verify.lua lint
.lua/bin/lua scripts/verify.lua test
.lua/bin/lua scripts/verify.lua parse
```

Preset maintenance: `/folio dump` and `/folio check`; see [docs/presets.md](docs/presets.md). No guide presets ship in this release.

### Local release package

Tags use CalVer `YYYY.M.D` without a `v` prefix. The TOC version token is expanded only in the package. To build and verify the local release candidate without publishing:

```sh
python scripts/package_release.py 2026.9.29
python scripts/test_package_release.py
```

The deterministic ZIP is written to the Git-ignored `.release/` directory. It contains only the explicit runtime allowlist, `LICENSE` and `CHANGELOG.md`. GitHub release publishing waits for the reusable CI gate; Wago and CurseForge use their GitHub integrations, without a second API uploader.
