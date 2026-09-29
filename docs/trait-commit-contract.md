# Folio commit completion contract

Applies to the first release, 2026.9.29. Source validation is not an in-game acceptance test.

## Blizzard evidence

The `Gethe/wow-ui-source` `live` branch resolved to
`09b9db7948abc9b9648dedaab51eb0cf3ee67b31` during this investigation. Links below are pinned to that tree.

- [Midnight landing page](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ExpansionLandingPage/Blizzard_MidnightLandingPage.lua#L1-L2): Folio system 48, tree 1186. `RunesOfPowerMixin:OnLoad` calls the shared talent base and selects system 48.
- [Folio frame XML](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ExpansionLandingPage/Blizzard_MidnightLandingPage.xml): `RunesOfPowerFrame` inherits `AutoCommitTraitFrameTemplate`.
- [Auto-commit template](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_AutoCommitTraitFrame.xml#L4) inherits `TalentFrameBaseTemplate`. [Auto-commit Lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_AutoCommitTraitFrame.lua#L23-L47) checks readiness, performs the selection operation, then calls the inherited commit method. Auto-commit does not mean synchronous completion.
- [Shared commit implementation](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua#L1639-L1663) starts commit state and a backup timeout before returning `C_Traits.CommitConfig`. [Completion handling](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua#L343-L364) separately handles config updates/failure. Therefore a true return is acceptance, not proof of a completed save, including for the Folio.
- [Generated C_Traits documentation](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua): `CommitConfig(configID)` returns a boolean (92–105); `ConfigHasStagedChanges(configID)` returns a boolean (107–119); `IsReadyForCommit()` has no config argument (549–556). `GetStagedChanges` explicitly describes selection swaps as a previously committed entry plus a different pending selection (340–357). `TraitNodeInfo` exposes `entryIDsWithCommittedRanks` separately from `activeEntry` (1017, 1028). A staged `activeEntry` must not be used as confirmation. Both trait-config update and commit-failure events carry a config ID; they do not carry a FolioSwap request ID.

## Addon contract

All production `C_Traits` calls remain in `Core/FolioApi.lua`.

- `read_current()` and selection-difference decisions use committed entry IDs. Saving a profile while a commit is in flight never saves its staged choices as though they were committed.
- `apply(selections)` checks config/readiness/editability and refuses pre-existing staged changes (`cannot_edit`) before staging anything. It does not purchase empty rows.
- `applied` contains only confirmed changed node IDs. A rejected synchronous commit is rolled back immediately and returns `commit_failed` with an empty `applied` list, as before.
- An accepted commit produces `reason = "pending"`, an empty `applied` list, the existing skip list, and an internal `pending` token containing the config ID, changed nodes, and a copied map of requested non-skipped selections (including rows already matching).
- `verify(result)` accepts a pending result and only reads API state. It requires the same config ID, readiness, no staged changes, and exactly the requested committed entry on every non-skipped requested row. Only then does it return confirmed `applied` nodes. A changed config or settled mismatch returns `commit_failed`, never success. It does not infer acknowledgement from an event, readiness alone, or `activeEntry`.
- `Actions` checks immediately, then polls pending results up to 20 times at 0.5-second timer intervals (nominally 10 seconds; frame/timer delays may extend wall-clock time). An unresolved result becomes `commit_timeout`, with a message saying completion was **not confirmed**, not that the server definitely rejected it. Pending results are silent. Terminal results retain normal skip reporting.
- Watchers capture a request generation, spec, profile source/name and selections. A newer valid apply, player spec/login event, changed spec, removed/changed profile, or changed automatic assignment invalidates the old report. Manual applies do not change the assigned automatic profile. Canceling a watcher does not cancel a save already accepted by the server.
- Manual applies and terminal/accepted automatic submissions invalidate stale pre-submit retry callbacks and combat continuations. Existing automatic `busy`/`unavailable` retries remain timer-based: one immediate attempt plus five retries at two-second intervals. New spec/login triggers retain their fresh retry budget and combat deferral.
- **After acceptance there is no automatic resubmission or rollback**, including on rejection, supersession, or timeout. A newer Blizzard/manual edit may own the config; no API request ID proves otherwise. On failure/timeout, inspect the Folio before explicitly trying again. Existing staged changes must be resolved in the game UI rather than silently merged or discarded by FolioSwap.
- Trait events are neither registered nor used for completion. Unrelated events cannot confirm/fail a request. Polls can observe completion even when no trait event is delivered to the addon.

## Regression evidence and remaining client check

The original production path was reproduced under Lua 5.1 with a fixture separating staged and committed entries: after an accepted commit was rejected, committed entry 1001 remained, chat still claimed one rune applied, and zero timers remained. The first new test failed on that immediate success message before production changes.

The fixture now separates `SetSelection`, accepted `CommitConfig`, and explicit simulated server resolution. Tests cover delayed success, asynchronous rejection, stuck/late completion, staged-vs-committed reads, manual/spec/profile/config supersession, external edits, unrelated events, and combat/retry interactions. Existing immediate-success tests simulate a completed server resolution, not just a true return.

A focused in-game smoke is still required after final review and a separately authorized installation: manual apply and automatic spec switching should report success only after the actual runes match; rapid manual/spec changes and combat deferral must not emit stale successes or override a newer manual request through an old retry. Check that Save current during a pending change reflects committed runes. If a save is naturally blocked or interrupted, confirm there is no false success. Do not manufacture network failures or require screenshots. Earlier visual/functional acceptance predates this behavior change and does not validate it.
