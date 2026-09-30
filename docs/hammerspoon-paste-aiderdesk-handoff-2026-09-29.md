# AiderDesk handoff: format on explicit paste

Implement the following change in
`/Users/kareemh/MeinCodex/Codebasis/github.com/neumachen/dotfiles`.
Read the applicable repository instructions first. The user explicitly chose
AiderDesk as the implementation agent for this task, overriding the repository's
default choice of Claude Code for this task only. Codex remains the analyst and
reviewer. Do not edit AGENTS.md to change the repository-wide role policy.
This is a source-only implementation request for AiderDesk; do not deploy,
reload Hammerspoon, commit, push, or dispatch other agents without separate
authorization.

## Goal and decisions

Replace the existing WezTerm copy-time Markdown formatter with an explicit
paste-time formatter. The user has selected these behaviors:

- Copy normally through any route. Neither Command+C nor Command+Shift+C
  opens a chooser or rewrites the clipboard.
- Command+V remains the application's ordinary paste, with no interception.
- Command+Option+V opens the language chooser for current clipboard text,
  regardless of which application supplied that text.
- Confirming a language formats the text as a Markdown fenced block and
  automatically pastes it once into the destination window where the user
  invoked the shortcut.
- Keep the formatted block on the clipboard afterwards. Do not schedule a
  restore of the original clipboard. Subsequent ordinary pastes reuse it.
- Escape or chooser dismissal cancels the operation: no write and no paste.

The user reports that the current copy-time implementation seems to work
during their testing. This is a general user-reported smoke test, not evidence
that every item in the previous manual checklist passed. The workflow change
is a preference change, not a newly reproduced failure.

## Scope and existing evidence

Primary source:
`private_dot_config/exact_hammerspoon/init.lua`.
Tests:
`private_dot_config/exact_hammerspoon/tests/hs_fake.lua` and
`private_dot_config/exact_hammerspoon/tests/copy_fence_test.lua`.
The tests directory is already excluded from deployment in `.chezmoiignore`.
Rename the behavior test to match the paste feature if useful.

Read `docs/hammerspoon-copy-completion-2026-09-29.md` for the previous
implementation and regression history. Preserve it as historical evidence;
write a separate paste-feature completion report. This handoff supersedes
the old requirements to trigger on copy and never auto-paste.

The existing implementation retains native objects under `_G.dotfiles`,
guards asynchronous callbacks, associates chooser rows with request IDs,
and checks clipboard generation before formatting. Preserve the relevant
protections. Copy-time polling, the WezTerm origin restriction, and the
copy event tap/watchdog become unnecessary if a normal Hammerspoon hotkey
satisfies the new contract. Prefer that simpler implementation.

Preserve Hyper+H/L, the retained config watcher, existing language presets,
indentation and text content. Do not change WezTerm, tmux, Karabiner, Homebrew,
Kando, or unrelated working-tree files. No new dependency is needed.

## Behavior and implementation requirements

1. Register Command+Option+V as a global shortcut; consume that shortcut so
   the destination does not also execute its native action. Do not intercept
   ordinary copy/paste or extra modifier combinations. Handle registration
   failure visibly. Keep the hotkey and all native asynchronous objects
   reachable. Do not add a repeat handler that repeatedly formats or pastes.
2. On invocation capture the destination application and window, and a stable
   clipboard text snapshot with change-count checks around the read. Do not
   watch future copy events. Empty or non-text data, an unstable snapshot,
   or an unavailable destination should produce a brief explanation and no
   clipboard mutation or generated paste. Non-text ordinary Command+V still
   belongs entirely to the destination application.
3. Permit one active request. Repeated invocations while choosing or awaiting
   focus must not create overlapping choosers or duplicate pastes. Bind rows
   and any delayed work to the request; discard stale results. Cleanup must
   be idempotent, including cancellation, exceptions and reload.
4. Retain preset, custom-tag and untagged-fence choices. Correct the existing
   exact-preset query quirk as part of this chooser flow: typing `lua` and
   pressing Enter must select `lua`, not the first untagged row. Custom tags
   must not contain newlines or fence delimiters. Preserve the payload's
   Unicode and whitespace. Use a fence long enough for any backtick run in
   the payload so copied code containing triple backticks remains intact.
5. Before writing or generating paste, ensure the captured destination still
   exists and the intended window has regained focus after chooser dismissal.
   A fixed delay alone is not proof of focus. Use bounded, retained deferred
   work if necessary; cancel on timeout, destination closure or user-directed
   focus changes. Do not send paste to whichever unrelated app happens to be
   frontmost. Check modifiers before emitting the synthetic Command+V so
   held Option/Control/Shift does not change its meaning. Do not synthesize
   Enter, Return or character-by-character typing.
6. Recheck clipboard generation after waiting for focus and immediately
   before formatting. A newer clipboard write cancels the request without
   overwriting it or pasting stale text. After a successful formatting write,
   issue exactly one ordinary Command+V to the validated destination. Guard
   against a detected newer clipboard write before dispatch. Keep the block
   on the clipboard; there is no restoration timer.
7. A failed formatting write must never generate paste. Preserve the existing
   ownership-aware failure recovery: a failed write may have cleared the
   pasteboard or may have lost ownership to another writer. Do not restore
   the snapshot over detected newer text or non-text data. Document the
   remaining non-atomic check/write limitation rather than claiming to solve
   it. Sending a keystroke also does not acknowledge application consumption.
8. No implicit unfencing: formatting acts on the clipboard snapshot as it
   exists when invoked. Repeated ordinary Command+V reuses the existing
   formatted block. Another explicit Command+Option+V is a new formatting
   request; do not introduce clipboard history or hidden content caches to
   infer an earlier raw payload.
9. Log request IDs, phases and failure reasons only. Never log clipboard
   payloads, custom queries, or destination document content. Retain guards
   around asynchronous callbacks and release request data on completion.

## Validation and completion

Update the fake only for APIs actually used; its behavior must follow native
Hammerspoon semantics, especially chooser dismissal/focus ordering. Replace
obsolete copy-trigger assertions rather than preserving tests for removed
behavior. Retain applicable lifetime, stale-request, concurrent-write and
failure-recovery regressions. Cover at least:

- Copy shortcuts pass through with no chooser/write; ordinary paste remains
  untouched; only the exact formatting shortcut triggers the new flow.
- Preset selection, typed exact preset, custom tag, untagged fence, indentation,
  Unicode and embedded backticks; one paste emitted after successful format.
- Escape, non-text/empty clipboard and failed snapshot: no write or paste.
- Changed clipboard while choosing and while awaiting focus: newer data kept,
  no stale paste; failed writes preserve newer text and non-text data.
- Missing/closed destination, focus timeout and destination changes: no paste
  into the wrong window; retained delayed work and chooser survive GC.
- Repeated shortcuts and stale callbacks produce at most one paste; the next
  fresh request still works after cancellation or failure.
- No delayed restoration after success; clipboard retains the formatted block.
- Hyper+H/L and retained config watcher remain intact; no content in logs.

Run scoped Lua tests, syntax checks, and `git diff --check`; verify tests remain
excluded by chezmoi without applying anything. Report exact commands/results.
Do not read or overwrite the real clipboard during source validation.

Provide a short operator checklist for a separately authorized live trial:
normal copy/paste, formatted paste into a scratch editor and a browser text
field, selecting by keyboard and mouse, immediate second ordinary paste,
cancellation, newer clipboard data, rapid invocation, focus changes and GC.
Use disposable samples. Native focus and paste delivery remain UNVERIFIED
until observed. No previous deployment authorization extends to this rewrite.

Finish with changed files, checks, known limitations, and the new completion
report path. Stop after source implementation and validation; do not deploy.

## References

- [Hammerspoon hotkeys](https://www.hammerspoon.org/docs/hs.hotkey.html#bind)
- [Synthetic paste keystroke](https://www.hammerspoon.org/docs/hs.eventtap.html#keyStroke)
- [Pasteboard API](https://www.hammerspoon.org/docs/hs.pasteboard.html)
- [Window focus](https://www.hammerspoon.org/docs/hs.window.html#focus)
