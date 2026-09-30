# Changelog

Versions use CalVer (`YYYY.M.D`), without a `v` prefix.

## [2026.9.30] - 2026-09-30

### Changed

- Add the Foliant style as the default, retaining Flat and existing skin preferences.
- Bring the Foliant panel closer to the Omnium Folio and distinguish the automatic
  profile assignment from a profile selected for manual use.
- Move appearance controls into WoW Options → AddOns → FolioSwap. The Skin button and
  `/folio skin` open that category instead of a separate window. Panel scale does not resize
  the settings page; changes apply immediately and skin reset preserves profiles.

### Validation

- The owner confirmed that the installed candidate works as expected in game.
  This is user-reported acceptance; no screenshots were supplied or inspected.
- Automated checks cover skin migration, profile retention, style controls and
  Settings integration under Lua 5.1. Built-in guide presets are still not included.

## [2026.9.29] - 2026-09-29

First release.

### Features

- Save account-wide Omnium Folio rune profiles separately for each specialization, including all four Druid specs.
- Assign a profile to apply automatically on specialization changes or login. Apply another profile manually without changing that assignment.
- Queue pending changes during combat and retry briefly while the game is busy or the Folio is loading. FolioSwap never purchases runes in rows you have not unlocked; make those initial choices in the Omnium Folio yourself.
- Manage profiles in a compact panel below the Omnium Folio. Selecting a profile does not apply it.
- Customize accent color, background opacity and panel scale with account-wide settings and a skin reset that preserves profiles.
- Use English or German interface text and `/folio` commands for profile management.

### Fixes and validation

- Corrected skin-window layering so its controls remain visible above the background.
- Confirm accepted rune changes through bounded timer-based committed-state readback before reporting success. Pending selections alone are not treated as saved; asynchronous failures and unconfirmed timeouts do not produce success messages.
- Protect newer manual/spec/profile changes from stale completion reports and automatic retry callbacks. Save current reads committed runes, and pre-existing staged edits are not silently committed or discarded.
- Earlier in-game functional and visual acceptance covered the UI and corrected skin layering. The completion-verification change requires a new focused in-game smoke; it has only been source-validated and regression-tested so far. No screenshots were requested or provided.

### Limitations and license

- Built-in guide presets are not included. Create profiles from your own rune selections.
- Requires WoW Retail with the Omnium Folio available to the character; the package declares interface `120100`.
- All Rights Reserved under [LICENSE](LICENSE). MIT rights previously granted for older versions remain in effect.
