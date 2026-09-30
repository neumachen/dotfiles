# Paste formatter review and AiderDesk correction handoff

Review date: 2026-09-29. Verdict: source corrections required before live trial.
This reviews the working-tree implementation against
`docs/hammerspoon-paste-aiderdesk-handoff-2026-09-29.md`.

Independently verified: the existing suite reports 45 passed, 0 failed;
`loadfile` compiles init.lua, hs_fake.lua and paste_fence_test.lua;
`git diff --check` is clean. Additional simulations below expose gaps in
that suite. These are source/synthetic findings, not live desktop observations.
No implementation, deployed file, clipboard or application state was changed.

## AiderDesk assignment

Fix the findings below within the existing source-only scope. AiderDesk is
the user's selected implementer for this task; no model is prescribed.
Preserve ordinary copy and Command+V, the explicit Command+Option+V trigger,
one-request behavior, formatted clipboard retention, Hyper+H/L and watcher.
Do not deploy, reload Hammerspoon, commit, push or dispatch other agents.
Preserve unrelated edits and existing staging; do not reset the checkout.

### 1. P1: enforce the captured destination window

`private_dot_config/exact_hammerspoon/init.lua:299` explicitly accepts another
window of the same app. This violates requirement 5 of the handoff. A browser
or editor can have multiple windows with different documents; accepting a
different window can paste the payload into the wrong document.

`tests/paste_fence_test.lua:607` encodes this incorrect behavior as a passing
test. Reverse its expectation: no formatting write and no generated paste.
Also cover closing the captured window while its application remains alive.
Validate the captured app/window relationship and identity using real supported
Hammerspoon APIs; do not assume the fake's `Window:isValid()` is a native API.

The paste call at init.lua:332 is also untargeted. Focus is checked before
formatting/writing, and never checked again. Injecting a focus switch during
the successful write still emits Command+V with the unrelated app frontmost.
Revalidate immediately before dispatch and use Hammerspoon's explicit
application target where appropriate; application targeting alone does not
replace exact window validation. Document the remaining focus/delivery race.
Do not claim an atomic guarantee that the APIs cannot provide.

### 2. P2: check for newer clipboard data after the formatting write

At init.lua:330-332, a successful setContents is immediately followed by
Command+V without a generation check. Another process may write after our
successful write and before the key is posted. The current implementation
then requests a paste of that newer, unrelated content.

Add a post-write ownership/generation check against the expected result of
our own write, immediately before dispatch. A detected newer write must be
preserved, with no paste. Keep the already-correct failed-write recovery.
Document that changes after the final check or before the app reads the
clipboard cannot be made atomic. Add the success-then-interloper regression,
distinct from the existing tests where setContents itself returns false.

### 3. P2: reject malformed custom language tags consistently

init.lua:215-216 and :259 reject LF and triple backticks, but allow CR and
single/double backticks. `bad` + one backtick + `tag` and `bad\r tag` are both
offered as custom rows and pasted by the current code.

Use one shared validation rule for query rows and completion: reject CR/LF
and every backtick in a backtick-fenced info string. CommonMark forbids any
backtick in that info string, regardless of the fence length. Preserve
ordinary custom tags such as elixir and c++. Add query and completion-path
regressions for CR, LF, and one/two/three backticks.

Reference: https://spec.commonmark.org/0.31.2/#fenced-code-blocks

### 4. P3: provide the promised visible failure feedback

init.lua:363-386 only logs unavailable destination, unstable snapshot and
empty/non-text clipboard failures. The registration failure at :421-422 is
also log-only. A user pressing the shortcut sees nothing. Add a brief,
content-free visible explanation for these failures and test it. The current
tests named "brief explanation" never assert an alert or notification.
Avoid repeated notifications from duplicate invocations or polling.

## Test and report corrections

- Extend the fake's keystroke record to include the explicit application
  target, focused window and clipboard generation at dispatch. Assert actual
  routing data rather than just the number of V keystrokes.
- Exercise GC after choosing, while the focus/modifier timer is pending;
  the current active-request GC test collects before that timer exists.
- Test extra modifier combinations and hotkey-registration failure. Do not
  claim those paths are covered merely because normal invocation passes.
- Preserve applicable regressions and rerun the suite, syntax and diff checks.
- Correct the completion report: synthetic Command+V does not "deliver the
  paste atomically". Report key dispatch separately from observed insertion.
  The existing copy test was retained, not renamed. The handoff required
  preserving the historical completion report, not the obsolete test file.
  Keeping that file is acceptable if clearly labelled historical.
- Reconcile coverage claims with tests that actually exercise them. Keep
  native focus, window closure, GC and receiving-app behavior UNVERIFIED
  pending a separately authorized live trial.

Hammerspoon documents the optional application argument to keyStroke:
https://www.hammerspoon.org/docs/hs.eventtap.html#keyStroke

## Reproduction used in this review

Run from the repository root. This executes the actual config against the
fake only. It reads no real clipboard and posts no native keys.

```sh
/Users/kareemh/.local/share/mise/installs/lua/5.5.0/bin/lua - <<'LUA'
package.path = 'private_dot_config/exact_hammerspoon/tests/?.lua;' .. package.path
local fake = require('hs_fake')
local path = 'private_dot_config/exact_hammerspoon/init.lua'
local function start()
  local s = fake.load(path)
  s:pbWrite('sample payload')
  s:invokeHotkey({'cmd', 'alt'}, 'v')
  return s
end
local s = start()
local originalId = s.apps.wezterm.window:id()
s:choose('lua')
local second = setmetatable({sim=s, app=s.apps.wezterm, windowId=99, valid=true}, fake.Window)
second:focus()
s:advance(0.1)
print('same-app switch: captured=' .. originalId .. ', focused=' .. second:id() .. ', pastes=' .. #s.keyStrokes .. ' (expected 0)')

s = start()
local orig = s.hs.pasteboard.setContents
s.hs.pasteboard.setContents = function(contents)
  local ok = orig(contents)
  if ok then s:pbWrite('newer sample') end
  return ok
end
s:choose('lua')
s:advance(0.1)
print('newer write after successful format: pastes=' .. #s.keyStrokes .. ', newer preserved=' .. tostring(s.pb.text == 'newer sample') .. ' (expected no paste)')

s = start()
orig = s.hs.pasteboard.setContents
s.hs.pasteboard.setContents = function(contents)
  local ok = orig(contents)
  if ok then s.apps.brave.window:focus() end
  return ok
end
s:choose('lua')
s:advance(0.1)
print('focus changes during write: front=' .. s.front:name() .. ', untargeted pastes=' .. #s.keyStrokes .. ' (expected no paste into other app)')

for _, tag in ipairs({'bad`tag', 'bad\r tag'}) do
  s = start()
  s:typeQuery(tag)
  local offered = s:chooserRows()[1].lang == tag
  s:pressEnter()
  s:advance(0.1)
  print('invalid tag ' .. string.format('%q', tag) .. ': custom offered=' .. tostring(offered) .. ', pastes=' .. #s.keyStrokes)
end

s = fake.load(path)
s:pbWrite('')
local alerts = #s.alerts
s:invokeHotkey({'cmd', 'alt'}, 'v')
print('empty clipboard: user-facing alerts=' .. (#s.alerts - alerts) .. ' (expected brief explanation)')
LUA
```

Observed before corrections: each of the three dispatch cases emits one
paste; both invalid tags are offered and emit one paste; empty clipboard
produces zero user-facing alerts. Expected dispatch counts are zero for the
unsafe destination/newer clipboard cases.
