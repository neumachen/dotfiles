# Claude Code handoff: reliable Hammerspoon terminal copy

Implement the following bounded fix in:
`/Users/kareemh/MeinCodex/Codebasis/github.com/neumachen/dotfiles`

Read root and applicable child `AGENTS.md` instructions first. You are Claude
Code, the implementation agent. Proceed with source implementation; routine
choices do not require another planning round.

## Goal and authority

Make the existing WezTerm copy-to-Markdown language chooser reliable. Preserve
normal copying, the language presets/custom tags, Escape cancellation, and
Hyper+H/L space switching. Fix object lifetime, request timing, clipboard
ownership, and callback error handling.

Authorized: source changes, focused regression tests, and documentation.
Primary implementation file:
`private_dot_config/exact_hammerspoon/init.lua`.
Small adjacent Lua modules/tests are permitted if justified. Keep test and
documentation artifacts excluded from deployment using decoded chezmoi paths.

Do not install dependencies, apply chezmoi, edit deployed files, reload or
restart applications, enable IPC, inject live keystrokes, alter the user's
clipboard, change macOS permissions, commit, or push. Prepare host validation
instructions; live activation needs separate authorization. Do not add Kando.
Do not change WezTerm, tmux, Karabiner, or the existing space-switch mappings.

## Review evidence and its limits

The review on 2026-09-28 checked the entire 269-line Hammerspoon configuration
and the relevant WezTerm/tmux copy paths. At that time:

- Source `init.lua` and `~/.config/hammerspoon/init.lua` were byte-identical.
- `~/.hammerspoon` linked to `.config/hammerspoon`.
- Hammerspoon was running; the installed app reported version 1.1.1.
- Inspected WezTerm/tmux source and deployed copies also matched.
- Hammerspoon IPC was inaccessible, so no live tap state, Secure Input state,
  or garbage-collection failure was observed. On-disk equality does not prove
  which revision an already-running process loaded.
- An isolated Lua check loaded the actual config with simulated Hammerspoon
  APIs. It reproduced: suppression after switching away before the timer;
  false triggering after copying elsewhere then switching into WezTerm;
  formatting an unchanged old clipboard; and formatting replacement text
  written before chooser confirmation. These were synthetic reproductions,
  not live desktop tests. No harness file was retained; recreate focused tests.

Recheck current files/version before editing; line numbers below are review
locators, not assumptions that the files remain unchanged.

## Findings to address

1. **Unretained runtime objects.** Line 267 discards the watchdog returned by
   `hs.timer.doEvery`; lines 228 and 250 discard delayed timers. The local
   `wezTermCopyTap` is held by the watchdog callback after config execution.
   Hammerspoon 1.1.1 timer finalization stops the timer and releases its callback,
   which can make the tap collectible too. Tap finalization disables listening.
   The reload pathwatcher at line 5 is also discarded, and its finalizer stops
   watching. These are source-supported lifetime defects; their occurrence
   during a particular reported failure has not been observed.

2. **Origin checked too late.** Lines 222-234 wait 50/150 ms before checking
   the frontmost application. That does not identify the app receiving Copy.

3. **No verified copy result.** Lines 236-237 accept any nonempty clipboard.
   Lines 97-99 read it again on confirmation. No clipboard generation or
   request identity links the text to the originating copy.

4. **Overlapping requests and loose trigger.** Line 218 accepts Command+C
   with Control/Option also held, and does not reject auto-repeat. Each event
   schedules another request without cancelling or invalidating earlier work.

5. **Error handling ends before async work executes.** The outer `xpcall`
   protects scheduling, not the later timer or chooser callbacks. Native
   Hammerspoon may log those errors, but this handler has no coordinated
   cleanup/recovery for them. Clipboard-write success is also ignored.

6. **Comments assert incorrect behavior.** Hammerspoon 1.1.1 automatically
   re-enables taps on timeout/user-input disable notifications. Both the tap
   and timer use the main run loop. `query(nil)` clears the query but does not
   itself call the query-change callback synchronously; chooser presentation
   does refresh the query. Remove unsupported explanations instead of
   perpetuating them as facts.

7. **tmux is a different copy route.** In
   `private_dot_config/exact_wezterm/keybinds.lua:81`, both Command+C and
   Command+Shift+C invoke WezTerm `CopyTo Clipboard`. Neither copies a tmux
   selection. `dot_tmux.conf:108` copies tmux selections with y/Enter through
   `.tmux/yank.sh`; mouse-drag-end copying is unbound at line 131. Those tmux
   operations bypass this Command+C listener. A longer Shift+C delay cannot
   fix that mismatch. Document it; do not remap tmux in this change.

## Required implementation behavior

- Give the watcher, event tap, any watchdog, and outstanding timers explicit
  strong ownership for their intended lifetimes. A chunk-local variable alone
  is not sufficient if no surviving closure/module owns it. Avoid unnecessary
  global names; a single durable namespace/module is acceptable. Release
  completed/cancelled request resources and avoid retaining an unbounded list.
- Match only the intended Command+C / Command+Shift+C combinations, rejecting
  Control/Option variants and auto-repeat. Preserve the original key event
  even if the formatting handler encounters an error.
- Establish the originating application at the copy event using a supported,
  bounded mechanism; prefer bundle identity over a display-name string.
  Neither a delayed frontmost-app lookup nor an unchecked watcher cache is
  sufficient. Keep event-tap work minimal and nonblocking.
- Model one active copy request with an identity/generation. A newer valid
  request supersedes older timers, polling, and chooser results. Specify how
  a second copy is handled while the chooser is open; never let an old callback
  format a newer request.
- Observe clipboard completion with a bounded timeout rather than treating
  a fixed sleep as proof. Record the pasteboard generation before copying;
  allow copying the same text again when the generation changes. A pasteboard
  change alone does not identify its writer: use the available request context
  and cancel ambiguous cases conservatively. Document remaining attribution
  limits rather than claiming perfect ownership.
- Capture the verified text and its pasteboard generation for that request.
  On language confirmation, format that snapshot only if the request is still
  current and no intervening clipboard change has made the write unsafe.
  Otherwise cancel without overwriting newer clipboard content.
- Do not silently reject a valid WezTerm-origin request merely because the
  user switched to the destination app before the delayed callback. Preserve
  deliberate chooser confirmation; never auto-paste. Restore the window that
  was active immediately before the chooser opened, without forcing an old
  source window to the front. Do not reopen a dismissed/obsolete chooser.
- Failed/no-selection/empty/non-text copies must not format old clipboard
  text. Escape leaves the clipboard untouched. Preserve text whitespace and
  the existing choice of no language tag or a custom tag.
- Guard actual asynchronous entry points and reset request state on failure.
  Check clipboard-write results. Log concise diagnostics such as request ID,
  phase, timeout/cancellation reason, and errors; never log clipboard content.
- Treat Secure Input as an OS restriction, not something a restart loop can
  bypass. Keep a watchdog only if justified, retained, and bounded in behavior.
- Correct misleading comments. Do not fix timing by increasing sleeps or
  changing global chooser callbacks without demonstrated need.

## Validation and acceptance

First inspect Git state and preserve unrelated changes. Add focused tests that
exercise behavior, with injected timer/application/pasteboard interfaces where
needed. Demonstrate the relevant failures against the original code, then the
same scenarios passing after the fix. A mocked test is not proof of native
Hammerspoon object lifetime or desktop focus behavior.

Cover these cases:

1. Successful Command+C and Command+Shift+C; presets and custom tags.
2. Copy twice with identical text but distinct pasteboard generations.
3. No clipboard update, delayed update within timeout, timeout, empty/non-text.
4. Copy in WezTerm then switch apps; copy elsewhere then switch into WezTerm.
5. Unrelated clipboard update before language confirmation: preserve new data.
6. Rapid copies, auto-repeat, extra modifiers, and stale timer/chooser callbacks.
7. Escape and asynchronous exceptions; subsequent valid requests still work.
8. Failed clipboard writes are reported without leaving the handler wedged.

Perform available syntax checks, test runs, chezmoi target/exclusion checks,
and `git diff --check` without installing tools or applying configuration.

Provide a separate manual checklist for a later authorized live session:

- Reload, exercise copying, force Lua garbage collection, and repeat; confirm
  listener/watchdog/watcher survival and delayed callbacks after collection.
- Exercise real WezTerm selections and clipboard actions across app switches.
- Verify tmux y/Enter still copy normally without automatically invoking this
  chooser; do not claim Command+Shift+C is a tmux selection-copy command.
- Verify cancellation, focus restoration, repeated use, Secure Input recovery,
  full-screen use where relevant, auto-reload, and Hyper+H/L behavior.

Do not run these host interactions under this source-only authorization.

## References

- [Hammerspoon object lifetime guidance](https://www.hammerspoon.org/go/)
- [1.1.1 timer implementation](https://github.com/Hammerspoon/hammerspoon/blob/1.1.1/extensions/timer/libtimer.m)
- [1.1.1 event-tap implementation](https://github.com/Hammerspoon/hammerspoon/blob/1.1.1/extensions/eventtap/libeventtap.m)
- [1.1.1 pathwatcher implementation](https://github.com/Hammerspoon/hammerspoon/blob/1.1.1/extensions/pathwatcher/libpathwatcher.m)
- [1.1.1 chooser implementation](https://github.com/Hammerspoon/hammerspoon/blob/1.1.1/extensions/chooser/libchooser.m)
- [Pasteboard API](https://www.hammerspoon.org/docs/hs.pasteboard.html)
- [Chooser API](https://www.hammerspoon.org/docs/hs.chooser.html)

## Completion report

Explain changed files, object ownership, request/cancellation behavior, and
clipboard attribution limits. Give actual commands/results for source tests,
and mark native object lifetime, focus, permissions, and physical interaction
UNVERIFIED unless observed in a separately authorized live session. Provide a
scoped deployment/rollback procedure without executing it. Do not declare the
intermittent desktop problem resolved solely from mocked tests.
