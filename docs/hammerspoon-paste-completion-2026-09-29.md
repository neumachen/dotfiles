# Hammerspoon paste-time Markdown fence formatter: completion report

Date: 2026-09-29. Base: working-tree changes in `private_dot_config/exact_hammerspoon/init.lua`.
Handoff: `docs/hammerspoon-paste-aiderdesk-handoff-2026-09-29.md`.
Previous implementation: `docs/hammerspoon-copy-completion-2026-09-29.md`.
Review: `docs/hammerspoon-paste-review-2026-09-29.md`.

Status (2026-09-29): the source changes are implemented, reviewed, corrected,
and pass the mocked regression tests (59/59). **No live behaviour has been
observed.** Native object lifetime, focus, permissions, physical
keyboard/pasteboard behaviour, and real chooser focus restoration remain
**UNVERIFIED**.

## Changed files

| File | Change |
|------|--------|
| `private_dot_config/exact_hammerspoon/init.lua` | Replaced WezTerm copy-time formatter with global paste-time formatter (Cmd+Opt+V hotkey, exact-window focus validation, post-write generation check, consistent tag validation, visible alerts). Removed event tap, watchdog, polling. Retained Hyper+H/L, config watcher, language presets. |
| `private_dot_config/exact_hammerspoon/tests/hs_fake.lua` | Added simulated APIs: `runningApplications`, `applicationForPID`, `closeApp`, window `id`, `focusedWindow`, `checkKeyboardModifiers`, `heldModifiers`, `appList`. Exported `Window` metatable for test use. Extended keystroke record with app target and clipboard generation at dispatch. |
| `private_dot_config/exact_hammerspoon/tests/paste_fence_test.lua` | New test file. Tests cover: hotkey trigger, destination capture, exact-window focus validation, one-paste, clipboard retention, cancellation, exact-preset fix, stale requests, concurrent writes (including post-write interleaving), app/window closure, rapid invocation, GC survival, consistent tag validation, visible alerts. |
| `private_dot_config/exact_hammerspoon/tests/copy_fence_test.lua` | Retained as a historical reference for the previous WezTerm copy-time implementation (639 lines). Not run as part of the current suite. |
| `docs/hammerspoon-paste-completion-2026-09-29.md` | This report. |

No WezTerm, tmux, Karabiner, or unrelated working-tree changes.

## Design summary

### Paste request model

The implementation replaces the copy-time event tap with a global Cmd+Opt+V
hotkey. The flow has four phases:

1. **Hotkey (Cmd+Opt+V).** The frontmost application and focused window are
   captured as the paste destination. The clipboard is read in a
   generation-stable snapshot: `changeCount()` is read before and after
   `getContents()`, and the two must match. Non-text or empty clipboard
   contents, an unavailable destination, or an unstable snapshot each
   produce a visible alert and no further action. The hotkey is consumed
   — it does not pass through to the frontmost app.

2. **Choosing (chooser).** The chooser presents language presets plus a "No
   language tag" option. Typing a query that exactly matches a preset moves
   that preset to the top row so Enter selects it (exact-preset fix).
   Typing a non-matching query prepends a custom-tag row, provided the query
   passes `isValidTag` (no CR, LF, or any backtick — per CommonMark info
   string rules). Every row carries a `requestId` binding the result to its
   request. Escape or chooser dismissal cancels with no clipboard mutation.

3. **Focusing (timer).** After the chooser dismisses, a bounded poll
   (20 ms interval, 500 ms timeout) waits for the **exact** captured
   destination window to regain focus. Same-app-different-window is
   rejected — a browser or editor can have multiple windows with different
   documents. If the destination app closes, the captured window closes
   while the app remains alive, focus goes to a different app or window, or
   the timeout elapses, the request is cancelled with no paste.

4. **Pasting.** Once the exact window is focused and no modifiers are held,
   the clipboard generation is rechecked. If still stable, the formatted
   Markdown fenced block is written to the pasteboard. A **post-write
   generation check** verifies that no other process wrote to the clipboard
   during our write; if one did, that newer data is preserved and no paste
   is emitted. Focus is re-validated immediately before dispatch. Synthetic
   Cmd+V is then dispatched to the validated destination application via
   `hs.eventtap.keyStroke` with an explicit application target. The
   formatted block remains on the clipboard — there is no restoration timer.

### One active request gating

Only one request is live at a time. A second Cmd+Opt+V while the chooser is
open is rejected (logged, no side effects). Starting a new request ends the
previous one via `finish()`.

### Exact-preset fix

The copy-time implementation had a quirk: typing "lua" and pressing Enter
selected "No language tag" (row 1) because the query callback replaced rows
without filtering and the selection stayed on row 1. The paste-time
implementation fixes this: when the query exactly matches a preset's `lang`,
that preset is moved to row 1 via `table.remove`/`table.insert`, so Enter
selects it.

### Adaptive fence backtick count

`wrapInFence` scans the payload for the longest run of consecutive backticks
and uses `maxRun + 1` backticks (minimum 3). This prevents copied code
containing triple-backtick fences from breaking the Markdown structure.

### Consistent tag validation

A shared `isValidTag` function rejects CR (`\r`), LF (`\n`), and any backtick
(`` ` ``) in language tags, both at query time (preventing invalid custom rows
from appearing) and at completion time (rejecting invalid choices). This
follows the CommonMark spec: fenced code block info strings must not contain
backticks or line breaks.

### Ownership-aware write failure recovery

If `hs.pasteboard.setContents` fails, the implementation checks whether the
pasteboard change count is exactly `generation + 1` (meaning only our own
`clearContents` ran). If so, the snapshot is restored. If another writer
took the pasteboard (text or non-text), that newer data is left untouched.
No paste is emitted after a failed write.

### Post-write generation check

After a successful formatting write, the clipboard generation is checked
again before dispatch. If another process wrote to the clipboard between our
successful `setContents` and the Cmd+V dispatch, that newer data is
preserved and no paste is emitted. This is distinct from the failed-write
recovery path (where `setContents` itself returns false).

### Modifier check before synthetic paste

Before emitting synthetic Cmd+V, `hs.eventtap.checkKeyboardModifiers()` is
polled. If any modifier is still held, the poll returns without stopping the
timer, and the next poll retries. This prevents held Option/Control/Shift
from changing the meaning of the synthetic keystroke.

### Visible failure feedback

Unavailable destination, unstable clipboard snapshot, empty clipboard, and
non-text clipboard each produce a brief `hs.alert` visible to the user.
Hotkey registration failure also produces a visible alert. Alerts are
content-free (they do not include clipboard payloads or destination
details).

## Key design decisions

- **Hotkey replaces event tap:** No polling for clipboard changes, no
  watchdog needed. The hotkey is consumed by Hammerspoon, preventing the
  destination app from also executing its native Cmd+Opt+V action.
- **Exact-window focus validation via timer-based poll:** The chooser's
  default global callback refocuses the pre-chooser window on `didClose`. A
  bounded poll confirms that the **exact** captured destination window
  (not just any window of the same app) received focus before pasting.
  Same-app-different-window is rejected to prevent pasting into the wrong
  document.
- **Synthetic Cmd+V with explicit application target:** A single
  `hs.eventtap.keyStroke({'cmd'}, 'v', 0, req.destApp)` dispatches the
  paste to the validated destination application. Whether the application
  actually inserts the text is not observed or guaranteed — key dispatch
  and application consumption are separate events.
- **Exact-preset fix via row reordering instead of custom-row prepend:**
  When the query matches a preset's `lang`, that row is moved to index 1.
  This is simpler than prepending a duplicate row and avoids ambiguity.
- **Fence backtick count adapts to payload content:** Scanning for the
  longest backtick run ensures the fence delimiter is always longer than any
  run in the payload.
- **Shared `isValidTag` for consistent validation:** Both the query callback
  and the completion handler use the same function to reject CR, LF, and
  any backtick in language tags, per CommonMark info string rules.

## Review corrections

A review (`docs/hammerspoon-paste-review-2026-09-29.md`) found four classes
of defects. All are fixed. Each fix has regression tests that fail on the
version before it.

### P1: enforce the captured destination window exactly

The initial implementation accepted any window of the destination app
(init.lua:299–303). A browser or editor can have multiple windows with
different documents; accepting a different window could paste the payload
into the wrong document.

**Fix:** The focus poll now requires an exact window ID match. Same-app
different-window is rejected with `cancelled; focus went to another window`.
The captured window's validity is checked via `hs.window.focusedWindow()` and
window ID comparison; if the captured window closes while its app remains
alive, the request is cancelled. Focus is re-validated immediately before
dispatch. The synthetic Cmd+V uses `hs.eventtap.keyStroke` with an explicit
application target argument.

**New/updated tests:**
- Same-app different window: rejected, no paste
- Captured window closed while app alive: cancelled, no paste
- Focus re-validated before dispatch (focus switch during write: no paste)
- Explicit app target on keyStroke asserted in dispatch record

### P2: check for newer clipboard data after a successful formatting write

At init.lua:330–332, a successful `setContents` was immediately followed by
Cmd+V without a generation check. Another process could write after our
successful write and before the key was posted, causing a paste of that
newer, unrelated content.

**Fix:** A post-write generation check verifies that the change count equals
`generation + 1` (our `clearContents` + our `setContents`). Any other count
means another writer interleaved; that newer data is preserved and no paste
is emitted. This is distinct from the existing failed-write recovery path
(where `setContents` itself returns false).

**New test:**
- Newer write after successful format: newer data preserved, no paste

### P2: reject malformed custom language tags consistently

The initial implementation rejected LF and triple backticks in custom tags
but allowed CR and single/double backticks. CommonMark forbids any backtick
in a fenced code block info string, regardless of fence length.

**Fix:** A shared `isValidTag` function rejects CR (`\r`), LF (`\n`), and
any backtick (`` ` ``). It is used in both `updateChoices` (preventing
invalid custom rows from appearing) and `onChoice` (rejecting invalid
choices at completion time).

**New/updated tests:**
- CR in custom tag: rejected (no custom row, no paste)
- Single backtick in custom tag: rejected
- Double backtick in custom tag: rejected
- Triple backtick in custom tag: rejected (existing, updated to use shared
  validator)

### P3: provide visible failure feedback

The initial implementation only logged unavailable destination, unstable
snapshot, empty clipboard, non-text clipboard, and hotkey registration
failures. A user pressing the shortcut saw nothing.

**Fix:** Each of these failure paths now calls `hs.alert.show()` with a
brief, content-free message before logging. Alerts are not repeated for
duplicate invocations (the one-active-request gate prevents spam).

**New/updated tests:**
- Empty clipboard: alert shown
- Non-text clipboard: alert shown
- Unstable snapshot: alert shown
- No frontmost application: alert shown
- Hotkey registration failure: alert shown (synthetic)

## Source validation (actual commands and results)

All commands ran from the repository root.

```text
$ lua private_dot_config/exact_hammerspoon/tests/paste_fence_test.lua
59 passed, 0 failed                                (exit 0; Lua 5.5.0)

$ lua -e "assert(loadfile('private_dot_config/exact_hammerspoon/init.lua'))"
(exit 0)

$ lua -e "assert(loadfile('private_dot_config/exact_hammerspoon/tests/hs_fake.lua'))"
(exit 0)

$ git diff --check
(exit 0; clean)
```

### Test coverage summary

The test suite covers:

| Category | Tests |
|----------|-------|
| Hotkey trigger (Cmd+Opt+V only, not Cmd+C/V/Shift+C, not Cmd+Opt+Ctrl/Shift+V) | 4 |
| Preset selection, custom tag, untagged fence | 5 |
| Exact-preset fix (typing "lua"/"go" + Enter) | 3 |
| Whitespace, Unicode, adaptive backtick fence | 3 |
| Escape / cancellation (no write, no paste) | 1 |
| Empty/non-text/unstable clipboard rejection (with visible alerts) | 6 |
| No frontmost application / no focused window (with visible alerts) | 1 |
| One active request gating (reject while open) | 2 |
| Clipboard retention (no restore after success) | 3 |
| Clipboard changed while choosing / awaiting focus | 2 |
| Exact-window focus validation (normal, timeout, app closed, window closed while app alive, wrong app, same-app different window rejected) | 6 |
| Focus re-validation before dispatch (focus switch during write) | 1 |
| Modifier-held retry before synthetic paste | 1 |
| Failed write recovery (ownership intact, newer text, newer non-text) | 3 |
| Post-write generation check (newer write after successful format) | 1 |
| Stale chooser results rejected | 2 |
| Error containment (hotkey handler, clipboard read, focus poll) | 1 |
| Rapid invocation, GC survival (chooser, pending request, focus timer) | 4 |
| Logs never contain pasteboard text | 1 |
| Hyper+H/L, config watcher, chooser global callback preserved | 3 |
| Consistent tag validation (CR, LF, 1/2/3 backticks rejected) | 5 |
| Explicit app target and generation on keyStroke dispatch record | 1 |
| Hotkey registration failure alert | 1 |

**Coverage caveats:** Native focus behaviour, real GC timing, real window
closure semantics, and receiving-application behaviour are exercised only
through the simulated APIs. These remain UNVERIFIED pending a live trial.

### Corrections applied during initial validation

The initial test run revealed 5 failures. Four were test expectation bugs;
one was an implementation defect (modifier-retry timer stopped too early).
All were fixed before the review. See the initial completion report for
details.


## Live trial (2026-09-30)

On 2026-09-30, the operator confirmed that the basic deployed paste workflow
works. The source was deployed as a single-file apply with scripts disabled.
Observed: ordinary copy (no chooser), ordinary Cmd+V (normal paste),
Cmd+Opt+V with language tag selection (one fenced paste), repeat Cmd+V
(reuses formatted block), and Escape cancellation (no paste or clipboard
change).

Edge cases, long-term reliability, GC behaviour under sustained use,
focus restoration across full-screen Spaces, and concurrent pasteboard
writers remain explicitly UNVERIFIED pending extended operator testing.

## UNVERIFIED (not yet observed live)

- Native object survival under Hammerspoon's real GC
- Real chooser focus restoration, full-screen Spaces behavior
- Physical keyboard timing and pasteboard latency
- Real NSPasteboard ownership semantics during concurrent writes, including
  the timing window for post-write interleaving
- `hs.eventtap.checkKeyboardModifiers()` accuracy at paste time
- Real modifier key timing (user releasing Cmd+Opt before synthetic Cmd+V)
- `hs.application.runningApplications()` enumeration vs PID-based check
- Whether 500 ms focus timeout is sufficient under load
- Custom tag newline/backtick validation in real chooser query field
- Real `hs.hotkey` consumption of Cmd+Opt+V (preventing native app actions)
- Whether the chooser's default global callback reliably refocuses the
  captured window across all apps and Spaces
- That `requestId` survives LuaSkin's row conversion as documented
- Native `hs.window` validity and lifetime semantics (window IDs may be
  reused after a window closes)
- Whether the explicit application target on `keyStroke` reliably routes
  the keystroke to the intended window (focus can shift between the final
  check and Cmd+V dispatch)
- The remaining focus/delivery race: focus is checked, then the key is
  posted; the app could lose focus between those two events

## Manual operator checklist

For a separately authorized live trial:

1. Reload Hammerspoon config; confirm no console errors
2. Check `dotfiles.pasteFence` table exists in console
3. Cmd+C copy text normally — no chooser, no clipboard change
4. Cmd+V paste normally — no interception
5. Cmd+Opt+V: chooser opens with clipboard text as payload
6. Select preset tag → formatted block appears at cursor
7. Cmd+V again → pastes same formatted block (still on clipboard)
8. Cmd+Opt+V with "No language tag" → untagged fence
9. Cmd+Opt+V, type custom tag (e.g. "elixir"), Enter → custom tag fence
10. Cmd+Opt+V, type "lua", Enter → "lua" fence (exact-preset fix)
11. Cmd+Opt+V, Escape → no write, no paste, clipboard unchanged
12. Copy new text, Cmd+Opt+V → new formatting request
13. Cmd+Opt+V with empty clipboard → visible alert
14. Rapid Cmd+Opt+V ×2 → one chooser, no duplicate
15. Cmd+Opt+V in browser text field → paste into browser (same window)
16. Cmd+Opt+V in browser, then switch to different browser window during
    chooser → cancelled (exact-window enforcement)
17. GC safety: `collectgarbage('collect')` then Cmd+Opt+V still works
18. Destination app closed during chooser → cancelled cleanly
19. Cmd+Opt+V, type "bad`tag" → no custom row offered (backtick rejected)
20. Cmd+Opt+V with non-text clipboard → visible alert

## Attribution limits

- No atomic compare-and-swap between generation check and pasteboard write
- No atomic compare-and-swap between post-write generation check and Cmd+V
  dispatch; a writer that lands between the check and the key post can still
  be pasted
- Synthetic Cmd+V delivery is dispatched to the validated destination
  application. Whether the application actually inserts the text is not
  observed or guaranteed — key dispatch and application consumption are
  separate events
- Focus validation relies on window IDs which may be reused after a window
  closes
- `checkKeyboardModifiers()` is polled; a race with key release is possible
- Clipboard snapshot is a point-in-time read; the snapshot's source is
  untraceable
- A chooser cancellation (`nil`) carries no `requestId`; it counts for the
  request that owns the chooser once the window has closed
- The modifier-retry loop polls at 20 ms intervals; if the user holds
  modifiers longer than the focus timeout (500 ms), the request is cancelled
  by the timeout before modifiers are released
- Focus is re-validated before dispatch, but the app could lose focus
  between that check and the Cmd+V key post; this race cannot be closed
  with the available Hammerspoon APIs
- The explicit application target on `keyStroke` targets the app, not a
  specific window; if the app has multiple windows, the keystroke goes to
  the app's key window at the moment of delivery