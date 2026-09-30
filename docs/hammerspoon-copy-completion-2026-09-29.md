# Hammerspoon WezTerm copy chooser: completion report

Date: 2026-09-29. Base commit: `2538b6f9` (uncommitted working-tree changes).
Handoff: `docs/hammerspoon-copy-claude-handoff-2026-09-28.md`.
Revised twice on 2026-09-29. The first review found two defects (deadline
and stale results). A follow-up found that a failed formatting write
restored the copy unconditionally. See [Review corrections](#review-corrections).

Status (2026-09-29 15:56): the source changes are implemented and pass the
mocked regression tests (42/42). **The single file
`~/.config/hammerspoon/init.lua` was deployed at 14:33:56 as an authorized
live trial**, with a backup kept (see [Live trial
deployment](#live-trial-deployment-2026-09-29-single-file)).

**No live behaviour has been observed yet.** Whether Hammerspoon reloaded
the new config is not confirmed. Startup errors, post-GC object state and
all manual tests are awaiting operator results. Native object lifetime,
focus, permissions and physical keyboard/pasteboard behaviour remain
**UNVERIFIED**. The intermittent desktop problem is **not** claimed to be
resolved.

## Changed files

| File | Change |
| --- | --- |
| `private_dot_config/exact_hammerspoon/init.lua` | Rewrote the copy chooser (request model, ownership, guards, watchdog); retained the reload watcher. The Hyper+H/L block, language presets and fence format are byte-identical. |
| `private_dot_config/exact_hammerspoon/tests/hs_fake.lua` | New. Simulated Hammerspoon 1.1.1 APIs with a virtual clock, GC finalizers, a blockable run loop (`stall`) with NSTimer-style late firing, saved or native-order chooser results, and another process writing during a pasteboard write (`duringNextWrite`). |
| `private_dot_config/exact_hammerspoon/tests/copy_fence_test.lua` | New. 42 behaviour scenarios; takes an optional `init.lua` path. |
| `.chezmoiignore` | Ignores decoded target `.config/hammerspoon/tests`, so only `init.lua` deploys. |
| `docs/hammerspoon-copy-completion-2026-09-29.md` | This report (`docs/` is already ignored). |

No WezTerm, tmux, Karabiner, space-switch, or `hs.chooser.globalCallback`
changes were made.

## Facts checked in Hammerspoon 1.1.1 sources

These were read from the tagged sources on GitHub, not observed live:

- `timer_gc`, `eventtap_gc` and `watcher_path_gc` stop the object and unref
  its callback. `hs.timer.doAfter` / `doEvery` keep no reference to the
  returned object.
- `eventtap_callback` re-enables the tap on `kCGEventTapDisabledByTimeout` /
  `…ByUserInput`. If the Lua callback raises, it returns `NULL`, which drops
  the key event. The tap and timers use the main run loop.
- `HSChooserWindow.xib` sets `nonactivatingPanel="YES"`: the chooser takes
  keyboard focus without changing the frontmost application. `show()` runs
  the query callback (`controlTextDidChange`), `query(nil)` only clears the
  field, and losing key status without a choice calls the completion with
  `nil`. The default global callback refocuses the window that was
  frontmost at `willOpen`.
- The chooser calls its completion callback from only two places, and each
  hides the window first and runs synchronously on the main thread:
  - `tableView:didClickedRow:` reports a copy of a row from the *current*
    choices. It runs on a click, on Enter (also ⌘-Enter and ⌥-Enter), on
    ⌘1–⌘0, and on Lua `:select()`.
  - `cancel:` reports `nil`. It runs on Escape, when the window loses key
    status without a choice, and on Lua `:cancel()`. It has no visibility
    guard.
- `show()` replaces the rows (through the query callback) before the panel
  can take input.
- The `hs.chooser:choices` documentation says extra row keys are "retained
  by the chooser and returned to the completion callback".
- `hs.timer.absoluteTime()` pushes an integer number of nanoseconds.
- `setContents` calls `clearContents` and then returns the result of
  `setString`. After a failed write, the pasteboard holds one of two
  things. If nothing else wrote, it is empty (our `clearContents` only).
  If another process wrote after that clear, which is itself a reason the
  write can fail, it holds that process's data.
- `hs.hotkey` keeps bound hotkeys in its module table, so Hyper+H/L need no
  change.
- WezTerm (upstream `window/src/os/macos/clipboard.rs`) copies with
  `clearContents` followed by `writeObjects`, which is one change-count
  increment. This was not checked against the installed nightly binary.

## Object ownership

`init.lua` publishes one global table, `dotfiles` (a chunk-local alias is
used internally):

- `dotfiles.configWatcher`: the reload pathwatcher.
- `dotfiles.wezTermCopy.tap`: the keyDown event tap.
- `dotfiles.wezTermCopy.watchdog`: a 2 s tap health timer.
- `dotfiles.wezTermCopy.chooser`: the chooser.
- `dotfiles.wezTermCopy.active`: the single live request. Its poll timer
  lives at `active.timer`.

A finished or cancelled request has its timer stopped and released and its
text dropped, and it is no longer referenced. Only one request is ever held.

## Request and cancellation behaviour

1. **Key event (tap).** The keycode is 8 with Command held and no
   Control/Option/Fn. Shift is optional, so this covers ⌘C and ⌘⇧C.
   Auto-repeat is ignored. While the chooser is open, ⌘C belongs to its query
   field and starts nothing. The origin is the frontmost application
   captured at event time, matched by bundle ID `com.github.wez.wezterm`.
   Only then is the pasteboard change count read as the request baseline;
   this happens inside the tap, before WezTerm handles the key. A new
   request ends the previous one. ⌘C in another app cancels a request that
   is still waiting. The tap callback is guarded and always returns `false`,
   so the key always reaches WezTerm.
2. **Waiting (20 ms poll, deadline 500 ms).** The deadline is
   `startedAt + 500,000,000` in integer nanoseconds on
   `hs.timer.absoluteTime()`, where `startedAt` is read in the tap. Each poll
   first takes one clock sample:
   - At or after the deadline (`now >= deadline`), the request is cancelled
     (`timed out`) without accepting anything, even a change already on the
     pasteboard. The deadline instant itself counts as timed out.
   - Before the deadline, the request accepts exactly one change-count
     increment, reads the text, and re-checks the count after the read. More
     than one change, empty text, non-text contents or a change during the
     read cancel it.

   On schedule, the 480 ms poll is the last one that can accept a change.
   Switching apps does not cancel the request.
3. **Choosing.** The request stores the snapshot text and its change count.
   Every chooser row, including a typed custom-tag row, carries
   `requestId` for the request the chooser was opened for.
   - A **choice** is accepted only if its `requestId` equals the live
     request's id, that request owns the chooser (`chooserFor`), and the
     chooser window is closed.
   - A **cancellation** (`nil`) has no id. It is accepted only for the
     request that owns the chooser, and only once the window has closed.
     This is safe because hs.chooser always hides the window before
     reporting.
   - A **rejected** result is logged and changes nothing. In particular, it
     does not clear `chooserFor`.

   An accepted choice writes only if the change count is unchanged. Newer
   data seen before the write is therefore not overwritten. The protection
   is not atomic, though: a writer that lands between the check and the
   write can still be overwritten. Escape or losing focus leaves the
   pasteboard untouched.

   If the formatting write fails, the error is logged. The pasteboard may
   then be empty, or it may hold another process's data. The snapshot is
   written back only when the change count is exactly `generation + 1`. In
   that case the only change seen is `setContents`'s own `clearContents`,
   so the pasteboard should be empty. Any other count means another
   writer's data (text or not), and it is left untouched (`newer pasteboard
   data left untouched`). That restore is also not atomic.
4. **Errors.** Every asynchronous entry point (tap, poll, chooser result,
   query callback, watchdog) runs under `xpcall`. On failure the error is
   logged, the live request is ended, and the state is reset. Logs contain
   the request id, phase and reason, never pasteboard text (a test checks
   this).
5. **Watchdog.** It restarts a tap that is disabled for any reason other
   than the notifications Hammerspoon already handles, for example `start()`
   failing before Accessibility is granted. Failed restarts back off 4, 8,
   16 … up to 60 s. Secure Input transitions are logged only, because a
   restart cannot bypass Secure Input.

## Review corrections

The first review found two defects in the first version (1 and 2 below). A
follow-up review found a third in the second version (3 below). All three
are fixed. Each fix has regression tests that fail on the version before it.
Those versions were kept as the uncommitted copies `init.v1.lua` and
`init.v2.lua` for the comparisons under "Source validation".

### 1. A late poll could accept a change after the deadline

The first version checked the timeout only when the pasteboard was
unchanged. A poll delayed by a busy run loop could therefore accept a change
seen after 500 ms. `poll()` now checks the deadline before looking at the
pasteboard.

The new tests:

- **Delayed poll (the requested reproduction).** Advance through 480 ms
  with no change. Stall the run loop until 600 ms. Write one change at
  600 ms, then let the overdue poll run once. Expected: cancelled with
  `timed out`, no chooser, and the pasteboard holding exactly that change
  with no further change count.
- **Boundary, accepting side.** A change written at 470 ms is accepted by
  the 480 ms poll.
- **Boundary, cancelling side.** A change written at 490 ms is not accepted
  by the poll at exactly 500 ms.

The trade-off: if a write lands before 500 ms but the run loop delays every
poll past the deadline, a legitimate copy is cancelled. A late poll cannot
tell when a change was made, so cancelling is the conservative choice.

### 2. A stale choice could format and finish a newer request

In the first version, `onChoice` took `copy.active` as the target of any
result and cleared `chooserFor` before checking anything. The requested
reproduction failed:

1. Save A's preset row and its typed custom-tag row.
2. Dismiss A.
3. Open B's chooser.
4. Deliver A's saved row.

B's text was formatted and B was finished. A rejected result would also
have cleared `chooserFor`, making B's own later choice be ignored.

Rows now carry `requestId` and results are checked as described in step 3
above. Two tests cover this:

- A's saved preset row, custom row and a `nil` are delivered while B's
  window is open. B stays open, and B's own choice still formats B.
- Native order (hide, then report) is used for A's preset and custom rows.
  B is not formatted, stays live with `chooserFor` still bound to B, and
  the next copy works.

The waiting-request test now also delivers a `nil`.

### 3. A failed formatting write could overwrite newer clipboard data

The second version restored `req.text` whenever the formatting
`setContents` returned `false`. A write can fail because another process
took the pasteboard between hs.pasteboard's `clearContents` and its
`setString`. In that case the unconditional restore replaced that newer
data with the old copy.

The restore is now conditional on ownership, as described in step 3 above.
Two new tests reproduce the loss: another writer takes the pasteboard during
the formatting write with (a) newer text or (b) non-text data (an image).
Both require all of the following:

- the failure is logged;
- the newer data is still on the pasteboard;
- the change count has not moved past that writer's change;
- (for non-text) the next copy still formats normally.

The existing failed-write test, where ownership is intact and the pasteboard
is empty, still requires the copy to be put back.

The restore is still a second, non-atomic write. A writer that appears
between the ownership check and the restore can be overwritten, which is
the same no-compare-and-swap limit as the formatting write.

### Native reachability of the stale-result scenario

From the 1.1.1 facts above, hs.chooser reports only rows of the chooser that
is showing, synchronously, after hiding it, and `show()` installs the new
request's rows first. Also, a new request cannot start while the chooser is
open, because the tap ignores ⌘C then. So a *saved* row from A cannot be
delivered while B is open through hs.chooser in 1.1.1. The two stale-result
tests are **synthetic**: they show that results are bound to their own
request, not that this path occurs natively. The binding guards against
changes to callback delivery or to this config, and against console use of
`:select()` / `:cancel()`.

Cancellations remain a limit. A `nil` carries no id, so a cancellation that
arrives after the window has closed is taken as the open request's own
cancellation. That is what Escape, losing focus and Lua `:cancel()` produce.

### Reconciliation

The first report claimed that "a late, duplicate or other-request chooser
result is ignored". That was not true while a newer request's chooser was
open, and its test covered only a newer request that was still waiting.
The claim now holds as stated in step 3, with the synthetic caveat above.
The handoff requirement "never let an old callback format a newer request"
is met this way. The handoff document itself is unchanged.

## Attribution limits (documented, not solved)

- Only a poll that starts before the 500 ms deadline can accept a change. If
  the run loop is blocked past the deadline, a copy that landed in time is
  cancelled.
- A chooser cancellation (`nil`) is not tied to a request. It counts for the
  request that owns the chooser once the window has closed (see above).
- A change count proves that the pasteboard was written, not who wrote it.
  Suppose WezTerm writes nothing (no selection) and another app changes the
  pasteboard within 0.5 s without ⌘C (menu copy, Universal Clipboard,
  scripts). That text is offered in the chooser.
- A non-activating panel from another app (a launcher, say) open over
  WezTerm receives ⌘C while WezTerm is still frontmost.
- An activation that has not yet reached `NSWorkspace` when ⌘C arrives
  (click then ⌘C within milliseconds) can misattribute the origin.
- There is no atomic compare-and-swap between the final change-count check
  and `setContents`. This applies both to the formatting write and to the
  ownership-checked restore after a failed write.
- `eventTargetUnixProcessID` is logged with each request so a live session
  can judge whether it gives a stricter origin check. At `kCGSessionEventTap`
  it may be 0; that is unknown.

## Source validation (actual commands and results)

All commands ran from the repository root.

```text
$ lua private_dot_config/exact_hammerspoon/tests/copy_fence_test.lua
42 passed, 0 failed                                (exit 0; Lua 5.5.0)

# second version, before the ownership correction (a working-tree copy; never committed)
$ lua private_dot_config/exact_hammerspoon/tests/copy_fence_test.lua "$TMPDIR/init.v2.lua"
40 passed, 2 failed                                (exit 1)
FAIL  newer text survives a failed formatting write
      pasteboard: expected "newer text", got "terminal text"
FAIL  newer non-text data survives a failed formatting write
      pasteboard kind: expected "image", got "text"

# first version, before the first review corrections (a working-tree copy; never committed)
$ lua private_dot_config/exact_hammerspoon/tests/copy_fence_test.lua "$TMPDIR/init.v1.lua"
36 passed, 6 failed                                (exit 1)
FAIL  the poll at the deadline cancels even with a change waiting
FAIL  a poll delayed past the deadline cancels instead of accepting
FAIL  saved results from request A cannot touch B's open chooser
FAIL  A's result in native order (hide, then report) leaves B live
FAIL  newer text survives a failed formatting write
FAIL  newer non-text data survives a failed formatting write

$ git show HEAD:private_dot_config/exact_hammerspoon/init.lua > "$TMPDIR/init.orig.lua"
$ lua private_dot_config/exact_hammerspoon/tests/copy_fence_test.lua "$TMPDIR/init.orig.lua"
13 passed, 29 failed                               (exit 1)
```

Each earlier version fails exactly the tests for the defects it contained.

- The second version restored the old copy over the newer text and over
  the image.
- The first version also opened the chooser at 600 ms in the delayed-poll
  test, and formatted B with A's `lua` row in the saved-row test.

The original `HEAD` failures, grouped by handoff finding:

| Finding | Failing scenarios against the original |
| --- | --- |
| 1 lifetime | GC loses the tap, watcher and watchdog (`enabled event taps after collection: expected 1, got 0`); a pending request is lost to GC |
| 2 origin too late | switching apps before the write suppresses the chooser; copying elsewhere then switching into WezTerm opens it |
| 3 no verified copy | no pasteboard update formats the old clipboard; a late update is missed; an update after the timeout is offered; a change at or after the deadline is accepted (boundary and delayed poll); a newer write before confirming is formatted; two changes are not treated as ambiguous; a copy in another app while waiting is not cancelled |
| 4 overlap / loose trigger | rapid copies present twice; a superseded request presents; ⌘C inside the chooser re-presents; auto-repeat triggers; ⌘⌃C / ⌘⌥C / ⌘Fn-C / Hyper+C trigger; a duplicate result re-wraps; A's saved rows format B (open, and in native order) |
| 5 async errors | errors in poll, key handling and confirmation escape to Hammerspoon; a failed write is silent, and in the ownership-intact test it leaves the pasteboard empty; in both ownership-loss tests the failure is not logged (the original never restores, so the newer data itself survives there) |
| design additions | watchdog retries every tick (60 in 60 s); no Secure Input diagnostic |

The original also fails "logs never contain pasteboard text", but only
because an injected error escapes. It does not leak text.

Of the 13 tests the original passes, 12 cover behaviour the rewrite must
preserve, such as presets, custom tags, whitespace, Escape and Hyper+H/L.
The 13th, "a stale chooser result cannot touch a newer waiting request",
passes only by coincidence: the original formats whatever the pasteboard
holds when you confirm.

**Mutation check.** 29 single protections were removed from the corrected
`init.lua` one at a time. Twenty-eight of the mutants fail at least one
test. Those added in the review passes cover:

- no deadline check;
- a deadline check only when the pasteboard is unchanged;
- `>` instead of `>=` at the deadline;
- no `requestId` on rows;
- no `requestId` check;
- no open-window check;
- no `chooserFor` binding check;
- a rejected result clearing `chooserFor`;
- an unconditional restore;
- never restoring;
- the ownership check off by one (`~= generation`).

The previous mutant "no restore after failed write" is now covered by
"never restoring".

The one surviving mutant removes the explicit supersede call, which is
intentionally redundant: the poll's stale-timer check ends the old request
on its next tick with the same observable behaviour.

The first mutation run also showed that `onChoice`'s
`phase == 'choosing'` check was redundant with `chooserFor == req.id`,
because the two are set and cleared together. It was removed, and the
waiting-request test gained a `nil` delivery so the remaining check is
tested on its own.

Other checks:

- `lua -e "assert(loadfile(…))"` and `luajit -bl` compile all three files.
- `stylua --check`: the test files are clean. In `init.lua`, the only
  differences are the pre-existing Hyper+H/L block and the `fenceLanguages`
  table, which were left unformatted to keep them byte-identical.
- `lua-language-server --check` with the repo `.luarc.json` at Hint level:
  "no problems found".
- `selene` (temporary std, `lua53` base; this build has no `lua54`): no
  undefined or unused variables. The remaining output is style noise
  (one-line `if … end` produced by the repo's stylua setting, deliberate
  `_G`) plus a false `loadfile` arity error.
- `luacheck` could not run: the installed luacheck 1.2.0 fails to load under
  Lua 5.5. This is a pre-existing tooling issue and nothing was installed.
- `chezmoi target-path`: the tests map to `~/.config/hammerspoon/tests/…`.
  `chezmoi ignored` lists `.config/hammerspoon/tests`, and `chezmoi managed`
  lists only `exact_hammerspoon/init.lua` under that directory.
- The scoped `chezmoi … --use-builtin-diff diff ~/.config/hammerspoon/init.lua`
  shows only the `init.lua` rewrite.
- `git diff --check`: clean.

The mocks model the 1.1.1 behaviour listed above. They cannot prove real
finalizer timing, window focus, run-loop ordering or WezTerm/pasteboard
latency.

## UNVERIFIED (not yet observed live)

- Native object survival and delayed callbacks under Hammerspoon's real GC.
- Which config revision the running Hammerspoon process had loaded when the
  failure occurred.
- Real chooser focus and restoration, including full-screen Spaces.
- The frontmost application at event time under fast app switching.
- WezTerm's one-increment write in the installed build, and whether 0.5 s is
  long enough under load.
- Secure Input, Accessibility permission and watchdog behaviour.
- `eventTargetUnixProcessID` values at the session tap.
- How late the real run loop delivers polls under load. The late-firing
  model (a late timer fires once, then keeps its schedule) follows NSTimer's
  documented behaviour, not an observation.
- That `requestId` survives LuaSkin's row conversion as documented.
- How a real formatting write fails when another process takes the
  pasteboard mid-write. The fake follows NSPasteboard's ownership rule: a
  write after another process has changed the pasteboard since our
  `clearContents` is rejected, and that process's data stays. That rule and
  the one-increment `clearContents` are assumptions, not observations.
  Either way the restore only happens at exactly `generation + 1`, so an
  extra change always leaves the pasteboard alone.
- Whether our own `hide()` of a key chooser makes it resign key and report
  a `nil` re-entrantly. If it does, that `nil` is rejected, because
  `chooserFor` and `active` are cleared before `hide()`.

## Observed, not changed

- **Typing an exact preset name and pressing Enter picks the first row ("No
  language tag").** The query callback replaces the rows without filtering,
  and the selection stays on row 1. This is from reading the source and was
  not observed live. Arrow keys, a mouse click or ⌘1–⌘0 pick presets
  correctly. It is a candidate follow-up and was kept here to preserve
  existing behaviour.
- `~/.config/hammerspoon/Spoons` is an empty, unmanaged directory inside an
  `exact_` target. The file-scoped apply below does not touch it.

## Manual checklist for a later authorized live session

Watch the Hammerspoon console for `wezcopy` lines throughout.

1. Reload and confirm there are no console errors. In the console, check that
   `dotfiles.wezTermCopy.tap:isEnabled()`,
   `dotfiles.wezTermCopy.watchdog:running()` and
   `dotfiles.configWatcher ~= nil` are all true.
2. Run `collectgarbage('collect')` twice, repeat step 1, then do a real
   copy.
3. Force GC during pending requests: run
   `dotfiles.gcProbe = hs.timer.doEvery(0.01, function() collectgarbage('collect') end)`,
   do several ⌘C copies, then run
   `dotfiles.gcProbe:stop(); dotfiles.gcProbe = nil`. The chooser should
   still appear every time.
4. Real WezTerm selections: ⌘C and ⌘⇧C with a preset, "No language tag"
   and a custom tag. Paste into an editor and inspect the fence and
   whitespace.
5. ⌘C with no selection: no chooser, and a `timed out` log line.
6. ⌘C in WezTerm, then ⌘Tab away at once: the chooser still appears and
   focus stays on the destination app, not WezTerm. Also try the reverse:
   copy in a browser, switch to WezTerm, and confirm no chooser appears.
7. While the chooser is open, ⌘C inside its query field, then choose: the
   pasteboard is not overwritten. Escape: the pasteboard is unchanged, and
   the next copy works.
8. Rapid double ⌘C, holding ⌘C, and Hyper+C / ⌘⌥C / ⌘⌃C: at most one
   chooser for a real copy, and none for the modifier variants.
9. tmux copy-mode `y` and `Enter` still copy through `~/.tmux/yank.sh` and
   never open the chooser. ⌘⇧C is not a tmux selection copy.
10. Secure Input (for example, focus a password field): expect `Secure Input
    on`, no chooser, and no restart loop. Afterwards expect `off`, and
    copying works again.
11. Full-screen WezTerm Space: the chooser appears and focus returns.
12. Editing the config auto-reloads it; Hyper+H/L still switch Spaces.
13. Record the logged event target pids against
    `hs.application.get('com.github.wez.wezterm'):pid()`.
14. Throughout, `ignored a chooser …` lines should not appear in normal
    use. If one does, record the steps. It would mean a result was
    delivered outside the synchronous order read from the 1.1.1 source.

## Live trial deployment (2026-09-29, single file)

Authorized scope: deploy only `~/.config/hammerspoon/init.lua` and reload the
Hammerspoon config. No full apply, no apply scripts, and none of the
unrelated `README.md` / Homebrew working-tree changes.

| Step | Command / result |
| --- | --- |
| Pre-flight | Hammerspoon 1.1.1 was running (pid 3117). The deployed `init.lua` was byte-identical to `HEAD` (sha256 `ce0dcffe…`). chezmoi `hooks` are unset. `~/.local/state` is not chezmoi-managed. |
| Backup | `~/.local/state/hammerspoon-backups/init.lua.pre-wezcopy-20260929-143337.lua`: read-only (0444), sha256 `ce0dcffee5d2516d2e667f257c3e2e70d25faeadf71984f608e3bd3582de66e9`, byte-identical to the file it replaced |
| Gate | `lua private_dot_config/exact_hammerspoon/tests/copy_fence_test.lua` gave 42 passed, 0 failed |
| Diff | `chezmoi --source "$PWD" --refresh-externals=never --no-pager --use-builtin-diff --exclude scripts diff ~/.config/hammerspoon/init.lua` touched one file (`.config/hammerspoon/init.lua`, mode 100644 unchanged, +313/−86 lines) |
| Apply | At 14:33:56, `chezmoi --source "$PWD" --refresh-externals=never --no-pager --no-tty --exclude scripts apply ~/.config/hammerspoon/init.lua` exited 0. The deployed sha256 is `9f3165d9bfb492e82d522e8ff3f773ae852e051a8e49e6f14782efa0788cf7db`, equal to the source. `Spoons/` was untouched and `git status` was unchanged. |
| Reload | The old config's watcher may already have been garbage-collected. Hammerspoon's Lua console does not reach the unified log, and IPC/AppleScript are off, so the reload is confirmed in the Hammerspoon console (see [Live trial results](#live-trial-results)). |

### Scoped rollback

This restores the target only. Leave the source tree alone: it holds the
uncommitted implementation, and `git restore --source=…` would discard it.

```sh
cp ~/.local/state/hammerspoon-backups/init.lua.pre-wezcopy-20260929-143337.lua ~/.config/hammerspoon/init.lua
chmod 644 ~/.config/hammerspoon/init.lua
shasum -a 256 ~/.config/hammerspoon/init.lua   # expect ce0dcffe…
```

Then use Reload Config in the Hammerspoon menu. The new config's watcher
normally reloads on the copy by itself.

After a rollback, `chezmoi diff ~/.config/hammerspoon/init.lua` shows the
source ahead of the target. That is expected until the source is changed or
re-applied. The backup file (0444) is kept.

## Live trial results

As of 2026-09-29 15:56.

**Verified on disk.** These were checked from the shell, not in Hammerspoon:

- The deployed `init.lua` sha256 is `9f3165d9…`, equal to the source. Its
  mtime is still 14:33, so the optional `touch` watcher check has not been
  run.
- `Spoons/` is unchanged.
- The backup exists, is mode 0444, and has sha256 `ce0dcffe…`.
- Hammerspoon is still running as pid 3117.
- `git status` is unchanged, and nothing was committed.

**Not yet observed.** No console output or manual results have been
reported:

| Check | Status |
| --- | --- |
| New config loaded (`dotfiles` table present, `-- Done.`, no error lines) | not observed |
| Tap, watchdog, watcher and chooser present after `collectgarbage` ×2 | not observed |
| Watcher reloads after GC (`touch`) | not run |
| ⌘C / ⌘⇧C with presets, custom tag and "No language tag" | not observed |
| Copy, then switch to destination; focus stays there | not observed |
| Repeated copies, hold ⌘C, Escape, next copy | not observed |
| Clipboard update while chooser open is preserved | not observed |
| tmux `y` / Enter copy with no chooser | not observed |
| Hyper+H/L Spaces; Hyper+C no chooser | not observed |
| Typed exact preset + Enter picks "No language tag" (source-read quirk) | not observed |

Record results here as they are reported. If any check fails, use the
[scoped rollback](#scoped-rollback).
