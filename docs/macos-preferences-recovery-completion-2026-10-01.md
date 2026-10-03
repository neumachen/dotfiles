# macos-preferences recovery and reporting fixes — completion report

Implemented 2026-10-01 by Claude Code. Report written 2026-10-02.
Base: `HEAD` `9145eb84` (which contains the original feature, `d1af825c`).
**State: working-tree changes, not committed.** Nothing was applied, pushed or
dispatched.
Audience: ChatGPT in its analyst / prompt-author role (root `AGENTS.md`). This
report asks you to implement nothing; section 9 lists read-only checks and
section 10 lists commit scope and candidate follow-ups.
This report supplements `docs/macos-preferences-completion-2026-09-30.md`
(untracked, written against `d1af825c`); section 8 lists what in that report is
now out of date.

## 1. Outcome in one paragraph

Three defects in how `macos-preferences restore` recovers from and reports a
write that did not land were fixed, plus a stale documentation item. A
recovery is now read back and compared exactly (value, type, absence) before it
is reported as `reverted`; a recovery that cannot be confirmed is a failure that
keeps the backup path in its guidance and in the structured result; the
`verified` count no longer includes entries that a whole-key recovery undid; and
the tests now run the Python interpreter under test regardless of the caller's
`PATH` or `HOME`. The change is covered by 19 new tests (89 total). The first 17
were shown to fail against the old code before the fix; the other two were added
afterwards and are each guarded by a mutant that they kill (section 6).
**Fresh-Mac restoration, actual
current-host writes, the real `defaults write` argument forms, and physical
shortcut behaviour remain UNVERIFIED.**

## 2. What was asked

The task prompt (pasted by the user) required:

1. After `_revert` writes or deletes the prior value, export the destination and
   verify exact restoration (type and absence). Report "reverted" only after
   successful verification. Propagate failed or unverifiable recovery into the
   structured failure result and keep the backup path in the recovery guidance.
   Regression: existing fake backend, persistent
   `FAKE_DEFAULTS_MISPARSE=AppleEnabledInputSources`, no misparse limit. Defect:
   the original array stays a string but recovery reports success.
2. Correct `apply_plan`'s applied/verified count when whole-key recovery undoes
   earlier successful dictionary-entry changes. Regression: start with shortcut
   999, add 34 successfully, corrupt 64, revert the dictionary; final contents
   only 999 and the retained applied-change count zero.
3. Make the test subprocess environment select the intended Python even when the
   caller's `PATH` starts with mise shims and `HOME` is a temporary fixture.
4. Refresh the stale Hammerspoon discrepancy in `docs/macos-preferences.md`;
   preserve the separate unresolved Karabiner F19 decision.

Constraints: run the existing suite and the new regressions; preserve the
captured profile and unrelated work; do not change live preferences, run
`chezmoi apply`, reload applications, commit or push; keep fresh-Mac
restoration, actual current-host writes and physical shortcut behaviour
explicitly UNVERIFIED.

## 3. Root causes (reproduced before fixing)

The first 17 new tests were written before any fix and run against the unchanged
tool: 16 failed and 1 passed. The 16 were 4 assertion failures and 12 errors (11
because the in-process tests pass the new `backup=` argument, 1 because the
interpreter-pinning wrapper was not wired in yet). The 1 pass is a self-check that
a simulated failing shim really breaks a bare `env python3`. The four CLI-level
failures showed the reported defects exactly:

| # | Defect | Old behaviour | Where |
| --- | --- | --- | --- |
| 1 | Recovery success was assumed | `_revert` wrote or deleted, then logged `reverted … to its previous value` with no read-back. With a persistent misparse the original array stayed a string yet the log said reverted and the guidance carried no backup path. A failed recovery command was only logged, never recorded in the result | old `_revert` in `executable_macos-preferences` |
| 2 | Applied count ignored recovery | `applied += len(written) - len(mismatched)` ran before recovery. Entry 34 verified (counted), entry 64 failed, the whole key was put back so 34 vanished, and the CLI still printed `1 problem(s); 1 change(s) verified` | old `apply_plan` |
| 3 | Test interpreter followed the caller's PATH | `Sandbox.env()` passed the caller's `PATH` through; `fake_defaults` and the tool start with `#!/usr/bin/env python3`, so a shim-first `PATH` decided the interpreter. Observed in the reproduction: the first PATH entry of the child was the caller's shim directory | `test_macos_preferences.py` `Sandbox.env()` |
| 4 | Documentation | `docs/macos-preferences.md` still said the live Hammerspoon file (424 lines) differed from the working tree (467) and `HEAD` (269) | docs |

## 4. What changed (uncommitted)

`git diff --stat`: 5 tracked files, +507 / −40, plus 1 new file and the untracked
2026-09-30 report.

| File | Change |
| --- | --- |
| `dot_local/bin/executable_macos-preferences` | `Recovery` and extended `ApplyResult`; `_same_state`, `_where`, `recovery_hint`; rewritten `_revert` and `apply_plan`; `_apply` summary and guidance; usage text |
| `private_dot_config/macos-preferences/tests/test_macos_preferences.py` | `ScriptedBackend` and helpers; `RecoveryVerificationTests` (9), `AppliedCountTests` (5), `InterpreterPinningTests` (4); `MemoryBackend.export` now deep-copies; `Sandbox` pins `PATH` |
| `private_dot_config/macos-preferences/tests/pinned_python.py` (new, 40 lines) | Wrapper `python3` that `exec`s `sys.executable`; `path_with_pinned` puts it first on `PATH`, idempotently |
| `private_dot_config/macos-preferences/tests/test_hook.py` | Hook environment uses the pinned interpreter; new test proves which interpreter ran |
| `private_dot_config/macos-preferences/tests/fake_defaults` | `FAKE_DEFAULTS_MISPARSE` accepts `Key/entry` to corrupt one dictionary entry; logs the interpreter that ran it to `python.log` |
| `docs/macos-preferences.md` | Recovery semantics; Hammerspoon item refreshed; explicit UNVERIFIED row for current-host writes; test-environment note; test count |

`profile.json`, the hook template and `.chezmoiignore` were not changed.

### Behaviour and API

- `apply_plan(backend, plan, log, backup=None)`. New optional `backup`.
- `ApplyResult` gains `recoveries: List[Recovery]`, `undone: int`,
  `backup: Optional[str]` and the property `unrecovered`. `applied` and `domains`
  now mean "still confirmed in effect after any recovery".
- `Recovery(domain, scope, key, verified, wrote, detail)` is the structured
  record. `verified` is true only after a fresh export matches the pre-run state
  exactly (`strict_eq`, so `1` ≠ `1.0` ≠ `true`; absent matches only absent).
- Success text: `reverted <domain> [scope] <key> to its previous value (confirmed
  by read-back)`. If the key is already at its previous value, `… is still at its
  previous value; nothing to revert` and no write is made.
- Failure text: `could not restore <key> (<expected vs read back>); the previous
  value is saved in <backup>/before.json; recover with: macos-preferences
  rollback <backup>`, plus a `recovery not verified` entry in `result.failures`
  and a summary naming the keys that `could NOT be confirmed back`.
- Counting: changes that verified earlier under a key later put back are counted
  only if the post-recovery export still shows them; otherwise `undone` increases.
  Exit status is unchanged (1 on any failed write or recovery).
- Unchanged by design: after a verification mismatch the run still stops and
  later domains are not attempted; command failures still continue.

## 5. Requirement-by-requirement

| # | Requirement | How it is met | Evidence |
| --- | --- | --- | --- |
| 1 | Verify recovery by export; type and absence | `_revert` (`:1110`) re-exports after the write or delete and compares with `_same_state` (`:1092`) | `test_recovery_must_restore_the_exact_type_not_just_an_equal_value`, `test_recovery_of_an_absent_key_is_verified_by_absence`, `test_a_delete_that_leaves_the_key_behind_is_an_unverified_recovery` |
| 1 | Report reverted only after verification | Success is logged only after the read-back matches | `test_a_recovery_that_does_stick_is_reported_as_reverted_after_read_back`; the persistent-misparse test asserts no `reverted` anywhere in stderr |
| 1 | Failed or unverifiable recovery propagates | `Recovery` records, `result.failures` entries, `result.unrecovered`, summary lines, exit 1 | `test_structured_result_carries_the_failed_recovery_and_the_backup_path`, `test_an_unreadable_destination_makes_the_recovery_unverifiable`, `test_a_failing_recovery_command_is_reported_even_if_the_state_cannot_be_checked` |
| 1 | Backup path retained in guidance | `recovery_hint` (`:1103`); `_apply` passes `backup=` | `test_persistent_misparse_makes_recovery_fail_and_the_cli_says_so` asserts `rollback <backup>` and `<backup>/before.json` on the failure line itself and that `before.json` still holds the original array |
| 1 | The stated regression | Existing fake, persistent misparse, no limit: array stays a string, tool exits 1 and says it could not restore | the same test; it asserts the stored value really is a `str` |
| 2 | Correct applied count | `apply_plan` (`:1149`) re-checks earlier verified changes against the post-recovery export | `test_cli_reports_zero_verified_when_recovery_undoes_the_earlier_entry` (`1 problem(s); 0 change(s) verified`, only 999 left), `test_structured_result_has_zero_retained_changes_and_no_counted_domain` (`applied` 0, `undone` 1, `domains` 0) |
| 2 | Counting stays correct elsewhere | Other keys and domains stay counted; if recovery fails only still-confirmed changes count; unreadable post-recovery state counts none | `test_changes_in_other_keys_and_domains_stay_counted`, `test_when_recovery_fails_only_changes_still_confirmed_in_effect_are_counted`, `test_unconfirmable_changes_are_not_counted_when_the_read_back_after_recovery_fails` |
| 3 | Intended interpreter regardless of PATH/HOME | `pinned_python.py`; applied to `Sandbox.env()`, the in-process environment patch, and the hook test environment | `test_cli_runs_with_shims_first_on_the_callers_path_and_a_fixture_home` (HOME asserted to be the fixture), `test_in_process_backend_also_ignores_a_shim_first_on_the_callers_path`, `test_the_pinned_python3_is_exactly_the_interpreter_running_the_tests`, `test_hook_environment_resolves_python3_to_the_interpreter_under_test` |
| 4 | Refresh Hammerspoon; keep Karabiner | Item 2 rewritten as "no longer different (checked 2026-10-01)"; Karabiner item kept with a dated "still different" line | See §6 for the facts rechecked |

## 6. Verification performed

All read-only unless stated. Dates 2026-10-01 and rechecked 2026-10-02.

| Check | Result |
| --- | --- |
| Full suite, Python 3.14 | 89 tests OK |
| Full suite, system `/usr/bin/python3` 3.9.6 (what a new Mac has) | 89 tests OK |
| Both of the above with a failing `python3` shim placed first on `PATH` | 89 tests OK on both (run 2026-10-01, after the last code change; not repeated on 2026-10-02) |
| Tests that failed before the fix | 16 of the first 17 new tests; the 17th is a self-check that the simulated shim really breaks `env python3` (passes before and after). The two tests added later (in-process shim, hook interpreter proof) were checked by mutation instead |
| Mutation checks on the tool (12 deliberately broken copies run through the suite) | 12 of 12 killed: success claimed without read-back match, type-blind `==` comparison, absence not compared, applied still counts undone entries, counts changes whose read-back failed, domain counted when all its changes were undone, failed recovery missing from failures, missing from the structured result, backup path dropped from guidance, not passed to `apply_plan`, no already-at-previous shortcut, read-back failure treated as success |
| Mutation checks on the test environment (temp mirror of the repo, shim-first `PATH`) | 4 of 4 killed: unpinned `Sandbox.env()`, unpinned in-process patch, wrong interpreter in the wrapper, unpinned hook environment |
| Live `validate`, `diff` against this Mac | profile valid (11 groups, 120 keys); `0 to add, 0 to change, 232 identical` |
| Fresh live capture vs shipped profile | byte-identical; `profile.json` unchanged from `HEAD` |
| State left on this Mac | `~/.local/state/macos-preferences`, `~/.config/macos-preferences`, `~/.local/bin/macos-preferences` do not exist |
| Lint | `ruff` (pyflakes + bugbear, minus the 3.10-only `zip(strict=)` rule): clean. `git diff --check`: clean. No stray bytecode |
| Hammerspoon fact for the doc | live `~/.config/hammerspoon/init.lua` is byte-identical to `HEAD` (467 lines; last commit touching it `524c2091`) |
| Karabiner fact for the doc | live F19 → Cmd+F5; repo F19 → Hyper+F5; still different |

## 7. UNVERIFIED (unchanged by this work)

1. **Restoring onto a fresh Mac.**
2. **Actual current-host writes**: `defaults -currentHost write` / `delete` against a
   real `ByHost` store. Only the scope and argument shape are tested, against the
   fake. The docs now carry this as its own UNVERIFIED row.
3. **The real `defaults write` argument forms** (bare XML fragments for
   dictionaries/arrays, `-dict-add` with an XML value, scalar floats that are not
   exactly float32, typed flags). No write was run against the real `defaults`.
4. **Physical shortcut behaviour** after logout/login, and the restart guidance.
5. **New, specific to this work:** every recovery path was exercised against
   `tests/fake_defaults` (my model of `defaults`) and scripted in-memory
   backends, never against the real `defaults`. Tests prove the tool handles the
   failure modes those fakes produce (misparse, type drift, a delete that leaves
   the key, an ignored write, an unreadable destination), not that the real
   `defaults` produces them.

## 8. Honest accounting

- **Interpreter defect scope.** The real mise shim, run with a replaced `HOME` on
  this Mac, still printed `Python 3.14.3`, so the original environment failure was
  **not reproducible with the real shim here**. The guard tests use a simulated
  failing shim, which reproduces the defect class, not this Mac's exact behaviour.
- **My own new tests had the same defect.** Running the whole suite with a failing
  shim first on `PATH` showed three of my new in-process tests failing (they call
  `DefaultsBackend` directly and inherit the caller's `PATH`). They were fixed and
  a regression added.
- **A mutant survived the first pass.** Dropping the interpreter pin from the hook
  tests was not detected, because the unpinned fallback `/usr/bin/python3` happens
  to work on this Mac. I added a check that makes the fake record which
  interpreter ran and asserts it. It then died. On a machine whose system Python
  is the interpreter under test that mutant would still be equivalent.
- **A sandbox network attempt.** During the shim experiment (real mise shims first
  on `PATH`) the sandbox denied one outbound connection to
  `static.rust-lang.org:443`; the cause was not confirmed (possibly a shim trying to
  install a toolchain). It was not allowed, not investigated further, and not part
  of the tests. No sandbox or permission setting was changed.
- **A long run moved to the background.** The mutation-check run exceeds the
  300-second tool limit and ran as a background task. Its output was read in full.
- **Nothing was committed or applied.** The repository still shows these changes
  as modified or untracked.

## 9. Read-only checks for review

Safe to run:

```sh
git status --short
git diff --stat
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s private_dot_config/macos-preferences/tests
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -m unittest discover -s private_dot_config/macos-preferences/tests
python3 dot_local/bin/executable_macos-preferences diff --profile private_dot_config/macos-preferences/profile.json   # expect: 232 identical
python3 dot_local/bin/executable_macos-preferences capture --stdout | cmp - private_dot_config/macos-preferences/profile.json
```

**Do not run** `restore` (without `--dry-run`), `rollback`, `chezmoi apply`,
`install.sh`, or `macos-defaults-snapshot restore`.

Where to look hardest (line numbers in the working tree):

| Concern | Location (`dot_local/bin/executable_macos-preferences`) |
| --- | --- |
| Structured recovery record and result | `class Recovery` `:1053`, `class ApplyResult` `:1069` |
| Exact-state comparison, guidance text | `_same_state` `:1092`, `recovery_hint` `:1103` |
| Recovery with read-back | `_revert` `:1110` |
| Retained-count logic | `apply_plan` `:1149` (the `retained` loop) |
| CLI summary and exit status | `_apply` `:1296` |
| Tests | `RecoveryVerificationTests`, `AppliedCountTests`, `InterpreterPinningTests` in `test_macos_preferences.py`; `pinned_python.py`; `test_hook.py` |

Things a reviewer may want to challenge:

- **Whole-key recovery rewinds the whole key** to its pre-run value, including any
  change made to the same key by something else between planning and recovery
  (the same semantics as `rollback`).
- **`rollback` uses the same write path.** In the scenario that triggers a failed
  recovery (the write path misparses), `rollback` can fail identically. The
  guidance says to set values by hand from `before.json`; there is no alternative
  write form attempted automatically.
- **`undone` also counts changes that could not be re-confirmed** after a recovery
  (not only ones known to be undone). The name is a simplification.
- **`applied` and `domains` also changed meaning for `rollback` runs**, which share
  `apply_plan`.
- **The hook hashes the tool.** The tool changed, so the hook will re-run on the
  next apply; it is a no-op while the Mac is in sync.
- **Log text changed.** Nothing in the repository parses it; the docs and tests
  reference the new wording.

## 10. Commit scope and follow-ups

Suggested scope (nothing is committed): the 5 modified tracked files plus the new
`private_dot_config/macos-preferences/tests/pinned_python.py`. Decide separately
whether to include the two untracked completion reports. Exclude any unrelated
work from other sessions. A conventional subject would be
`fix(macos): verify recovery and correct applied count in macos-preferences`
(no attribution trailer, per repository practice).

Candidate follow-ups for Claude Code prompts:

1. **Refresh or retire `docs/macos-preferences-completion-2026-09-30.md`** (see
   below), or fold both reports into one.
2. **Verify the real write path on a disposable account or VM**: run
   `macos-preferences restore --only dock --yes`, confirm the read-back passes, and
   if it reports a mismatch adjust the argument forms for the failing shape. Still
   the highest-value next step, and it also exercises the new recovery path for
   real.
3. **Karabiner F19** is still an open user decision (Cmd+F5 live, Hyper+F5 in the
   repo); do not bulk re-add.
4. **Optional:** an automatic alternative write form for recovery when the primary
   one misparses; renaming `undone`.

### What the 2026-09-30 report now gets wrong

| Statement there | Now |
| --- | --- |
| 70 tests; class counts | 89 tests; new classes listed in §4 |
| Mutation counts (tool 18 killed + 2 equivalent; hook 8 of 8) | Still true for that code; this change adds 12 tool and 4 environment mutants, all killed |
| §10 item 2: Hammerspoon docs item is stale | Fixed in the working tree (uncommitted) |
| "A mismatch reverts that key and stops the run" | Now also: the revert is read back, and an unconfirmable one is reported as a failure |
| Line references (`_revert :1067`, `apply_plan :1079`, `_dest_matches :1041`, file length 1,315) | Shifted: file is now 1,414 lines; see §9 |
| `tests/` described as three files | Four, plus `pinned_python.py`; `fake_defaults` grew |
