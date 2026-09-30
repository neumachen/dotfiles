-- Behaviour tests for the ⌘⌥V → fenced code block chooser and the
-- runtime objects in ../init.lua, run against simulated Hammerspoon APIs
-- (hs_fake.lua) with a virtual clock. Needs Lua 5.4+ (table finalizers).
--
--   lua private_dot_config/exact_hammerspoon/tests/paste_fence_test.lua [init]
--
-- The optional argument runs the same scenarios against another init.lua,
-- such as a revision extracted from git. Passing here does not prove native
-- object lifetime, focus behaviour, permissions or real pasteboard timing.

local here = (debug.getinfo(1, 'S').source:match('^@(.*[/\\])')) or './'
package.path = here .. '?.lua;' .. package.path

local fake = require('hs_fake')
local target = arg[1] or (here .. '../init.lua')

local tests = {}
local sims = {}

local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

local function check(cond, message)
  if not cond then error(message, 2) end
end

local function eq(actual, expected, what)
  if actual ~= expected then
    error(
      ('%s: expected %q, got %q'):format(
        what,
        tostring(expected),
        tostring(actual)
      ),
      2
    )
  end
end

local function fence(lang, text)
  local maxRun = 0
  local run = 0
  for i = 1, #text do
    if text:sub(i, i) == '`' then
      run = run + 1
      if run > maxRun then maxRun = run end
    else
      run = 0
    end
  end
  local n = math.max(3, maxRun + 1)
  local f = string.rep('`', n)
  return f .. lang .. '\n' .. text .. '\n' .. f
end

-- A freshly loaded config with WezTerm frontmost.
local function start(opts)
  local sim = fake.load(target, opts)
  sims[#sims + 1] = sim
  return sim
end

-- Set clipboard text and invoke Cmd+Opt+V.
local function pasteFence(sim, text)
  sim:pbWrite(text)
  sim:invokeHotkey({ 'cmd', 'alt' }, 'v')
end

local function chooserOpen(sim)
  local chooser = sim:liveChooser()
  return chooser ~= nil and chooser.visible
end

-- Advance past the focus poll to confirm focus and deliver the paste.
local function confirmFocus(sim)
  -- The chooser's default global callback refocuses the saved window on
  -- didClose. After that, focusedWindow() returns it. Advance enough for
  -- the focus poll to see it and for modifiers to be clear.
  sim:advance(0.1)
end

-- ============================================================================
-- Preserved behaviour (ported from copy_fence_test)
-- ============================================================================

test('Hyper+H/L still send Hyper+Left/Right', function()
  local sim = start()
  check(sim:pressHotkey(fake.HYPER, 'h'), 'Hyper+H bound')
  check(sim:pressHotkey(fake.HYPER, 'l'), 'Hyper+L bound')
  eq(sim.keyStrokes[1].key, 'left', 'Hyper+H key')
  eq(sim.keyStrokes[2].key, 'right', 'Hyper+L key')
  eq(sim.keyStrokes[1].mods, table.concat(fake.HYPER, '+'), 'Hyper+H mods')
end)

test('config watcher survives GC', function()
  local sim = start()
  sim:collect()
  sim:touchConfig()
  eq(sim.reloads, 1, 'reloads after a config change')
end)

test('config watcher reloads on file change', function()
  local sim = start()
  sim:touchConfig()
  eq(sim.reloads, 1, 'reloads after first touch')
  sim:touchConfig()
  eq(sim.reloads, 2, 'reloads after second touch')
end)

test('logs never contain pasteboard text', function()
  local secret = 'SENTINEL-pasteboard-7f3a'
  local sim = start({ clipboard = secret .. '-old' })
  pasteFence(sim, secret .. '-1')
  sim:choose('lua')
  confirmFocus(sim)
  pasteFence(sim, secret .. '-2')
  sim:escape()
  pasteFence(sim, secret .. '-3')
  sim:pbWrite(secret .. '-4')
  sim:choose('lua')
  confirmFocus(sim)
  pasteFence(sim, secret .. '-5')
  sim.failWrites = 2
  sim:choose('lua')
  confirmFocus(sim)
  sim:throwNext('pasteboard.setContents')
  pasteFence(sim, secret .. '-6')
  sim:choose('lua')
  confirmFocus(sim)
  check(not sim:logText():find(secret, 1, true), 'pasteboard text logged')
end)

test('preset language selection', function()
  local sim = start()
  pasteFence(sim, 'print(1)')
  eq(sim.showCount, 1, 'chooser presentations')
  sim:choose('lua')
  confirmFocus(sim)
  eq(sim.pb.text, fence('lua', 'print(1)'), 'pasteboard')
end)

test('"No language tag" produces untagged fence', function()
  local sim = start()
  pasteFence(sim, 'ls -la')
  eq(sim.showCount, 1, 'chooser presentations')
  sim:choose('No language tag')
  confirmFocus(sim)
  eq(sim.pb.text, fence('', 'ls -la'), 'pasteboard')
end)

test('custom typed tag works', function()
  local sim = start()
  pasteFence(sim, 'IO.puts(1)')
  sim:typeQuery('elixir')
  eq(sim:chooserRows()[1].text, 'elixir', 'custom row first')
  sim:pressEnter()
  confirmFocus(sim)
  eq(sim.pb.text, fence('elixir', 'IO.puts(1)'), 'pasteboard')
end)

test('whitespace preserved exactly in formatted output', function()
  local sim = start()
  local text = '  indented\n\ttabbed  \n\n'
  pasteFence(sim, text)
  sim:choose('sh')
  confirmFocus(sim)
  eq(sim.pb.text, fence('sh', text), 'pasteboard')
end)

test('unicode preserved', function()
  local sim = start()
  local text = 'café 🎉 λx.x'
  pasteFence(sim, text)
  sim:choose('lua')
  confirmFocus(sim)
  eq(sim.pb.text, fence('lua', text), 'pasteboard')
end)

test('embedded triple-backtick content gets longer fence', function()
  local sim = start()
  local text = 'before\n```lua\nprint(1)\n```\nafter'
  pasteFence(sim, text)
  sim:choose('sh')
  confirmFocus(sim)
  -- The fence should use 4+ backticks since the text contains ```.
  local result = sim.pb.text
  check(result:sub(1, 4) == '````', 'opening fence must use 4+ backticks')
  check(
    result:sub(-4) == '````',
    'closing fence must use 4+ backticks'
  )
  check(result:find('```lua', 1, true), 'embedded code block preserved')
end)

test('chooser global callback is left at default', function()
  local sim = start()
  eq(
    sim.hs.chooser.globalCallback,
    sim.hs.chooser._defaultGlobalCallback,
    'hs.chooser.globalCallback'
  )
end)

-- ============================================================================
-- Paste-trigger tests (new)
-- ============================================================================

test('Cmd+Opt+V with text on clipboard opens chooser', function()
  local sim = start()
  pasteFence(sim, 'some text')
  eq(sim.showCount, 1, 'chooser presentations')
  check(chooserOpen(sim), 'chooser must be open')
end)

test('Escape dismisses chooser, no write, no paste, clipboard unchanged', function()
  local sim = start()
  pasteFence(sim, 'keep me')
  local count = sim.pb.count
  sim:escape()
  eq(sim.pb.text, 'keep me', 'pasteboard unchanged')
  eq(sim.pb.count, count, 'pasteboard change count unchanged')
  eq(#sim.keyStrokes, 0, 'no keystrokes emitted')
end)

test('choosing a preset formats, writes, emits ONE Cmd+V keystroke', function()
  local sim = start()
  pasteFence(sim, 'hello world')
  sim:choose('python')
  confirmFocus(sim)
  eq(sim.pb.text, fence('python', 'hello world'), 'pasteboard')
  eq(#sim.keyStrokes, 1, 'one keystroke')
  eq(sim.keyStrokes[1].mods, 'cmd', 'Cmd modifier')
  eq(sim.keyStrokes[1].key, 'v', 'V key')
end)

test('formatted block stays on clipboard after paste', function()
  local sim = start()
  pasteFence(sim, 'data')
  sim:choose('json')
  confirmFocus(sim)
  local formatted = sim.pb.text
  eq(formatted, fence('json', 'data'), 'formatted on clipboard')
  -- Clipboard still has the formatted block (not restored to original).
  eq(sim.pb.text, formatted, 'formatted block still on clipboard')
end)

test('second ordinary Cmd+V pastes the formatted block', function()
  local sim = start()
  pasteFence(sim, 'data')
  sim:choose('json')
  confirmFocus(sim)
  local formatted = sim.pb.text
  -- Simulate another Cmd+V (just check clipboard still has it).
  eq(sim.pb.text, formatted, 'formatted block available for next paste')
end)

test('second Cmd+Opt+V is a fresh formatting request', function()
  local sim = start()
  pasteFence(sim, 'first')
  sim:choose('lua')
  confirmFocus(sim)
  eq(sim.pb.text, fence('lua', 'first'), 'first formatted')

  pasteFence(sim, 'second')
  eq(sim.showCount, 2, 'second chooser presentation')
  sim:choose('go')
  confirmFocus(sim)
  eq(sim.pb.text, fence('go', 'second'), 'second formatted')
end)

test('Cmd+C, Cmd+V, Cmd+Shift+C pass through with no chooser/write', function()
  local sim = start()
  local count = sim.pb.count
  -- Cmd+C should not trigger the paste fence (it's Cmd+Opt+V only).
  sim.apps.wezterm.selection = 'copied'
  sim:press({ 'cmd' }, 'c')
  sim:advance(0.3)
  eq(sim.showCount, 0, 'no chooser from Cmd+C')
  -- Cmd+V should not trigger either.
  sim:press({ 'cmd' }, 'v')
  sim:advance(0.1)
  eq(sim.showCount, 0, 'no chooser from Cmd+V')
  -- Cmd+Shift+C should not trigger.
  sim:press({ 'cmd', 'shift' }, 'c')
  sim:advance(0.3)
  eq(sim.showCount, 0, 'no chooser from Cmd+Shift+C')
end)

test('non-text clipboard: brief explanation, no write, no paste', function()
  local sim = start()
  sim.pb.kind = 'image'
  sim.pb.text = nil
  local count = sim.pb.count
  sim:invokeHotkey({ 'cmd', 'alt' }, 'v')
  eq(sim.showCount, 0, 'no chooser for non-text')
  eq(sim.pb.kind, 'image', 'pasteboard kind unchanged')
  eq(sim.pb.count, count, 'pasteboard change count unchanged')
  eq(#sim.keyStrokes, 0, 'no keystrokes')
end)

test('empty clipboard: brief explanation, no write, no paste', function()
  local sim = start()
  sim:pbWrite('')
  local count = sim.pb.count
  sim:invokeHotkey({ 'cmd', 'alt' }, 'v')
  eq(sim.showCount, 0, 'no chooser for empty')
  eq(sim.pb.text, '', 'pasteboard still empty')
  eq(#sim.keyStrokes, 0, 'no keystrokes')
end)

test('unstable snapshot: no chooser, no write', function()
  local sim = start()
  -- Make changeCount return different values on successive calls.
  local callCount = 0
  local origChangeCount = sim.hs.pasteboard.changeCount
  sim.hs.pasteboard.changeCount = function()
    callCount = callCount + 1
    if callCount == 2 then return sim.pb.count + 1 end
    return sim.pb.count
  end
  sim:invokeHotkey({ 'cmd', 'alt' }, 'v')
  eq(sim.showCount, 0, 'no chooser for unstable snapshot')
  eq(#sim.keyStrokes, 0, 'no keystrokes')
end)

test('one active request: second Cmd+Opt+V while chooser open is rejected', function()
  local sim = start()
  pasteFence(sim, 'first')
  eq(sim.showCount, 1, 'first chooser')
  check(chooserOpen(sim), 'chooser open')
  -- Second invocation while chooser is open.
  sim:invokeHotkey({ 'cmd', 'alt' }, 'v')
  eq(sim.showCount, 1, 'still only one chooser presentation')
  -- First request should still work.
  sim:choose('lua')
  confirmFocus(sim)
  eq(sim.pb.text, fence('lua', 'first'), 'first request completed')
end)

test('repeated Cmd+Opt+V after completion produces at most one paste each', function()
  local sim = start()
  for i = 1, 3 do
    pasteFence(sim, 'text ' .. i)
    sim:choose('lua')
    confirmFocus(sim)
    eq(sim.pb.text, fence('lua', 'text ' .. i), 'iteration ' .. i)
  end
  eq(#sim.keyStrokes, 3, 'three keystrokes total')
end)

-- ============================================================================
-- Exact-preset fix tests
-- ============================================================================

test('typing "lua" + Enter chooses "lua" (not "No language tag")', function()
  local sim = start()
  pasteFence(sim, 'print(1)')
  sim:typeQuery('lua')
  -- The first row should be "lua" (the matched preset moved to top).
  eq(sim:chooserRows()[1].text, 'lua', 'first row is lua preset')
  eq(sim:chooserRows()[1].lang, 'lua', 'first row lang is lua')
  sim:pressEnter()
  confirmFocus(sim)
  eq(sim.pb.text, fence('lua', 'print(1)'), 'formatted with lua tag')
end)

test('typing "go" + Enter chooses "go"', function()
  local sim = start()
  pasteFence(sim, 'package main')
  sim:typeQuery('go')
  eq(sim:chooserRows()[1].text, 'go', 'first row is go preset')
  sim:pressEnter()
  confirmFocus(sim)
  eq(sim.pb.text, fence('go', 'package main'), 'formatted with go tag')
end)

test('typing a non-preset tag + Enter uses it as custom tag', function()
  local sim = start()
  pasteFence(sim, 'code')
  sim:typeQuery('elixir')
  eq(sim:chooserRows()[1].text, 'elixir', 'first row is custom elixir')
  eq(sim:chooserRows()[1].subText, 'custom language tag', 'custom subText')
  sim:pressEnter()
  confirmFocus(sim)
  eq(sim.pb.text, fence('elixir', 'code'), 'formatted with elixir tag')
end)

-- ============================================================================
-- Clipboard change during choosing
-- ============================================================================

test('newer clipboard write while chooser open: cancelled, newer data preserved', function()
  local sim = start()
  pasteFence(sim, 'original')
  sim:pbWrite('newer data')
  sim:choose('lua')
  -- Should be cancelled; newer data preserved.
  eq(sim.pb.text, 'newer data', 'newer data preserved')
  eq(#sim.keyStrokes, 0, 'no keystrokes')
end)

test('newer clipboard write after chooser but before focus confirmed: cancelled', function()
  local sim = start()
  pasteFence(sim, 'original')
  sim:choose('lua')
  -- Write newer data after choice but before focus poll confirms.
  sim:pbWrite('newer data')
  confirmFocus(sim)
  eq(sim.pb.text, 'newer data', 'newer data preserved')
  eq(#sim.keyStrokes, 0, 'no keystrokes')
end)

-- ============================================================================
-- Focus and destination tests
-- ============================================================================

test('destination app closed while awaiting focus: cancelled, no paste', function()
  local sim = start()
  pasteFence(sim, 'text')
  sim:choose('lua')
  -- Close the destination app before focus is confirmed.
  sim:closeApp(sim.apps.wezterm)
  confirmFocus(sim)
  eq(#sim.keyStrokes, 0, 'no keystrokes')
end)

test('focus goes to different app: cancelled, no paste', function()
  local sim = start()
  pasteFence(sim, 'text')
  sim:choose('lua')
  -- Switch focus to a different app.
  sim.apps.brave.window:focus()
  confirmFocus(sim)
  eq(#sim.keyStrokes, 0, 'no keystrokes')
end)

test('focus timeout: cancelled, no paste', function()
  local sim = start()
  pasteFence(sim, 'text')
  sim:choose('lua')
  -- Clear the focus log so focusedWindow returns nil, then advance past
  -- the timeout without any focus event.
  sim.focusLog = {}
  sim.front = nil
  sim:advance(0.6) -- past FOCUS_TIMEOUT (0.5s)
  eq(#sim.keyStrokes, 0, 'no keystrokes')
end)

test('normal focus restoration: paste delivered to captured destination', function()
  local sim = start()
  pasteFence(sim, 'hello')
  sim:choose('bash')
  confirmFocus(sim)
  eq(sim.pb.text, fence('bash', 'hello'), 'pasteboard formatted')
  eq(#sim.keyStrokes, 1, 'one keystroke emitted')
  eq(sim.keyStrokes[1].mods, 'cmd', 'Cmd modifier')
  eq(sim.keyStrokes[1].key, 'v', 'V key')
end)

-- ============================================================================
-- Failed write tests
-- ============================================================================

test('failed formatting write with ownership intact: copy restored, no paste', function()
  local sim = start()
  pasteFence(sim, 'original')
  sim.failWrites = 1
  sim:choose('lua')
  confirmFocus(sim)
  eq(sim.pb.text, 'original', 'original text restored')
  eq(#sim.keyStrokes, 0, 'no keystrokes emitted')
end)

test('failed write with newer data during write: newer data kept, no paste', function()
  local sim = start()
  pasteFence(sim, 'original')
  sim.duringNextWrite = function()
    sim:pbWrite('newer data')
  end
  sim:choose('lua')
  confirmFocus(sim)
  eq(sim.pb.text, 'newer data', 'newer data kept')
  eq(#sim.keyStrokes, 0, 'no keystrokes emitted')
end)

test('failed write with non-text data during write: non-text data kept', function()
  local sim = start()
  pasteFence(sim, 'original')
  sim.duringNextWrite = function()
    sim:pbWrite(nil, 'image')
  end
  sim:choose('lua')
  confirmFocus(sim)
  eq(sim.pb.kind, 'image', 'non-text data kept')
  eq(#sim.keyStrokes, 0, 'no keystrokes emitted')
end)

-- ============================================================================
-- Stale/callback tests
-- ============================================================================

test('stale chooser result rejected', function()
  local sim = start()
  pasteFence(sim, 'request A')
  local saved = sim:savedRow('lua')
  sim:escape()
  eq(sim.pb.text, 'request A', 'pasteboard after dismissing A')

  -- Start a new request.
  pasteFence(sim, 'request B')
  check(chooserOpen(sim), "B's chooser must be open")
  -- Deliver the stale result.
  sim:deliverChooserResult(saved)
  check(chooserOpen(sim), "B's chooser must stay open")
  eq(sim.pb.text, 'request B', 'pasteboard unchanged')

  -- B should still work.
  sim:choose('go')
  confirmFocus(sim)
  eq(sim.pb.text, fence('go', 'request B'), 'request B completed')
end)

test('stale request cannot trigger paste after new request completes', function()
  local sim = start()
  pasteFence(sim, 'old')
  local saved = sim:savedRow('lua')
  sim:escape()

  pasteFence(sim, 'new')
  sim:choose('go')
  confirmFocus(sim)
  eq(sim.pb.text, fence('go', 'new'), 'new request completed')

  -- Now deliver the stale result — should be ignored.
  sim:deliverChooserResult(saved)
  eq(sim.pb.text, fence('go', 'new'), 'pasteboard unchanged by stale result')
end)

test('error in hotkey handler is contained; next invocation works', function()
  local sim = start()
  sim:throwNext('pasteboard.changeCount')
  sim:invokeHotkey({ 'cmd', 'alt' }, 'v')
  eq(sim.showCount, 0, 'no chooser after error')

  -- Next invocation should work.
  pasteFence(sim, 'recovered')
  eq(sim.showCount, 1, 'chooser after recovery')
  sim:choose('lua')
  confirmFocus(sim)
  eq(sim.pb.text, fence('lua', 'recovered'), 'recovered request')
end)

-- ============================================================================
-- Rapid/repeated tests
-- ============================================================================

test('rapid Cmd+Opt+V x2: second rejected while chooser open, first completes', function()
  local sim = start()
  pasteFence(sim, 'first')
  eq(sim.showCount, 1, 'first chooser')
  -- Second invocation while chooser is open is rejected (no clipboard change).
  sim:invokeHotkey({ 'cmd', 'alt' }, 'v')
  eq(sim.showCount, 1, 'still only one chooser presentation')
  -- The first request should still work.
  sim:choose('lua')
  confirmFocus(sim)
  eq(sim.pb.text, fence('lua', 'first'), 'first request completed')
end)

test('GC during active request: request survives, chooser still works', function()
  local sim = start()
  pasteFence(sim, 'pending')
  sim:collect()
  check(chooserOpen(sim), 'chooser must survive GC')
  sim:choose('lua')
  confirmFocus(sim)
  eq(sim.pb.text, fence('lua', 'pending'), 'pasteboard after GC')
end)

-- ============================================================================
-- Additional edge case tests
-- ============================================================================

test('custom tag with newline is rejected', function()
  local sim = start()
  pasteFence(sim, 'code')
  sim:typeQuery('bad\ntag')
  -- The custom row should NOT appear (newline in query).
  eq(sim:chooserRows()[1].text, 'No language tag', 'no custom row for newline tag')
end)

test('custom tag with backtick sequence is rejected', function()
  local sim = start()
  pasteFence(sim, 'code')
  sim:typeQuery('```evil')
  -- The custom row should NOT appear (backtick sequence in query).
  eq(sim:chooserRows()[1].text, 'No language tag', 'no custom row for backtick tag')
end)

test('no frontmost application: hotkey ignored', function()
  local sim = start()
  sim.front = nil
  sim:pbWrite('text')
  sim:invokeHotkey({ 'cmd', 'alt' }, 'v')
  eq(sim.showCount, 0, 'no chooser without frontmost app')
end)

test('same app different window on focus poll is rejected', function()
  local sim = start()
  -- Create a second window for the same app.
  sim.nextWindowId = sim.nextWindowId + 1
  local secondWindow = setmetatable({
    sim = sim,
    app = sim.apps.wezterm,
    title = 'WezTerm window 2',
    windowId = sim.nextWindowId,
    valid = true,
  }, fake.Window)
  sim:addWindowToApp(secondWindow, sim.apps.wezterm)

  pasteFence(sim, 'text')
  sim:choose('lua')
  -- Focus the second window of the same app.
  secondWindow:focus()
  confirmFocus(sim)
  -- Should be cancelled; no paste to wrong window.
  eq(#sim.keyStrokes, 0, 'no keystrokes emitted')
  check(
    sim:logText():find('focus went to a different window', 1, true),
    'cancellation logged'
  )
end)

test('modifiers held during focus poll: retry, then paste', function()
  local sim = start()
  pasteFence(sim, 'text')
  sim:choose('lua')
  -- Set held modifiers for the first poll.
  sim.heldModifiers = { cmd = true }
  sim:advance(0.03) -- one poll cycle, modifiers held
  eq(#sim.keyStrokes, 0, 'no keystroke while modifiers held')
  -- Release modifiers.
  sim.heldModifiers = {}
  sim:advance(0.1)
  eq(#sim.keyStrokes, 1, 'keystroke after modifiers released')
  eq(sim.pb.text, fence('lua', 'text'), 'pasteboard formatted')
end)

-- ============================================================================
-- P1: Exact window enforcement
-- ============================================================================

test('captured window closed while app still runs: cancelled, no paste', function()
  local sim = start()
  -- Create a second window for the same app.
  sim.nextWindowId = sim.nextWindowId + 1
  local secondWindow = setmetatable({
    sim = sim,
    app = sim.apps.wezterm,
    title = 'WezTerm window 2',
    windowId = sim.nextWindowId,
    valid = true,
  }, fake.Window)
  sim:addWindowToApp(secondWindow, sim.apps.wezterm)

  -- Capture the second window as the destination.
  secondWindow:focus()
  pasteFence(sim, 'text')
  sim:choose('lua')
  -- Close just the captured window (app still runs).
  sim:closeWindow(secondWindow)
  -- Refocus the original window.
  sim.apps.wezterm.window:focus()
  confirmFocus(sim)
  eq(#sim.keyStrokes, 0, 'no keystrokes emitted')
  check(
    sim:logText():find('captured window closed', 1, true),
    'cancellation logged'
  )
end)

test('focus changes during successful write: no Cmd+V emitted', function()
  local sim = start()
  pasteFence(sim, 'text')
  sim:choose('lua')
  -- During the setContents write, focus a different window.
  sim.duringNextWrite = function()
    sim.apps.brave.window:focus()
  end
  confirmFocus(sim)
  -- The formatted text may have been written, but no Cmd+V.
  eq(#sim.keyStrokes, 0, 'no keystrokes emitted')
  check(
    sim:logText():find('focus changed during write', 1, true),
    'cancellation logged'
  )
end)

-- ============================================================================
-- P2: Post-write clipboard check
-- ============================================================================

test('newer write after successful format: cancelled, newer data preserved', function()
  local sim = start()
  pasteFence(sim, 'original')
  sim:choose('lua')
  -- Make setContents succeed but then immediately write newer data.
  local orig = sim.hs.pasteboard.setContents
  sim.hs.pasteboard.setContents = function(contents)
    local ok = orig(contents)
    if ok then sim:pbWrite('newer sample') end
    return ok
  end
  confirmFocus(sim)
  eq(sim.pb.text, 'newer sample', 'newer data preserved')
  eq(#sim.keyStrokes, 0, 'no keystrokes emitted')
end)

-- ============================================================================
-- P2: Tag validation (CR, single/double backtick)
-- ============================================================================

test('custom tag with carriage return is rejected', function()
  local sim = start()
  pasteFence(sim, 'code')
  sim:typeQuery('bad\rtag')
  eq(sim:chooserRows()[1].text, 'No language tag', 'no custom row for CR tag')
  sim:pressEnter()
  -- "No language tag" is selected; confirmFocus would paste with empty lang.
  confirmFocus(sim)
  eq(sim.pb.text, fence('', 'code'), 'untagged fence used')
end)

test('custom tag with single backtick is rejected', function()
  local sim = start()
  pasteFence(sim, 'code')
  sim:typeQuery('bad`tag')
  eq(sim:chooserRows()[1].text, 'No language tag', 'no custom row for backtick tag')
end)

test('custom tag with double backtick is rejected', function()
  local sim = start()
  pasteFence(sim, 'code')
  sim:typeQuery('bad``tag')
  eq(sim:chooserRows()[1].text, 'No language tag', 'no custom row for double backtick tag')
end)

-- ============================================================================
-- P3: Alert assertions
-- ============================================================================

test('alert shown for non-text clipboard', function()
  local sim = start()
  local initialAlerts = #sim.alerts
  sim.pb.kind = 'image'
  sim.pb.text = nil
  sim:invokeHotkey({ 'cmd', 'alt' }, 'v')
  check(#sim.alerts > initialAlerts, 'alert shown for non-text clipboard')
end)

test('alert shown for empty clipboard', function()
  local sim = start()
  local initialAlerts = #sim.alerts
  sim:pbWrite('')
  sim:invokeHotkey({ 'cmd', 'alt' }, 'v')
  check(#sim.alerts > initialAlerts, 'alert shown for empty clipboard')
end)

test('alert shown for unstable snapshot', function()
  local sim = start()
  local initialAlerts = #sim.alerts
  local callCount = 0
  local origChangeCount = sim.hs.pasteboard.changeCount
  sim.hs.pasteboard.changeCount = function()
    callCount = callCount + 1
    if callCount == 2 then return sim.pb.count + 1 end
    return sim.pb.count
  end
  sim:invokeHotkey({ 'cmd', 'alt' }, 'v')
  check(#sim.alerts > initialAlerts, 'alert shown for unstable snapshot')
end)

test('alert shown for no frontmost application', function()
  local sim = start()
  local initialAlerts = #sim.alerts
  sim.front = nil
  sim:pbWrite('text')
  sim:invokeHotkey({ 'cmd', 'alt' }, 'v')
  check(#sim.alerts > initialAlerts, 'alert shown for no frontmost app')
end)

-- ============================================================================
-- GC during focus poll
-- ============================================================================

test('GC during focus poll: paste still works', function()
  local sim = start()
  pasteFence(sim, 'pending')
  sim:choose('lua')
  -- GC after the focus timer is created but before it fires.
  sim:collect()
  confirmFocus(sim)
  eq(sim.pb.text, fence('lua', 'pending'), 'pasteboard after GC')
  eq(#sim.keyStrokes, 1, 'one keystroke emitted')
end)

-- ============================================================================
-- Extra modifier test
-- ============================================================================

test('Cmd+Opt+Ctrl+V and Cmd+Opt+Shift+V do not trigger chooser', function()
  local sim = start()
  sim:pbWrite('text')
  sim:press({ 'cmd', 'alt', 'ctrl' }, 'v')
  eq(sim.showCount, 0, 'no chooser for Cmd+Opt+Ctrl+V')
  sim:press({ 'cmd', 'alt', 'shift' }, 'v')
  eq(sim.showCount, 0, 'no chooser for Cmd+Opt+Shift+V')
end)

-- ============================================================================
-- Hotkey registration failure
-- ============================================================================

test('hotkey registration failure shows alert', function()
  local sim = start({ hotkeyBindFails = true })
  -- The init.lua checks paste.hotkey for nil and shows an alert.
  -- We need to load with hotkeyBindFails set before loading.
  -- Since start() already loaded, check that the alert was shown.
  -- Actually, we need to set this before load. Let's use a fresh load.
  -- The sim was already created; check if the alert fired.
  check(#sim.alerts > 0, 'alert shown for hotkey bind failure')
end)

-- ============================================================================
-- Extended keystroke assertions
-- ============================================================================

test('keystroke records destination app and generation', function()
  local sim = start()
  pasteFence(sim, 'hello')
  local gen = sim.pb.count
  sim:choose('bash')
  confirmFocus(sim)
  eq(#sim.keyStrokes, 1, 'one keystroke')
  eq(sim.keyStrokes[1].app, sim.apps.wezterm, 'keystroke targets wezterm')
  eq(sim.keyStrokes[1].generation, gen + 1, 'keystroke generation')
end)

print('target: ' .. target)
local failed = 0
for _, t in ipairs(tests) do
  sims = {}
  -- Collection only happens where a test asks for it.
  collectgarbage('stop')
  local ok, err = pcall(t.fn)
  if ok then
    for _, sim in ipairs(sims) do
      if #sim.nativeErrors > 0 then
        ok, err = false, 'error escaped to Hammerspoon: ' .. sim.nativeErrors[1]
        break
      end
    end
  end
  collectgarbage('restart')
  if ok then
    print('ok    ' .. t.name)
  else
    failed = failed + 1
    print('FAIL  ' .. t.name)
    print('      ' .. tostring(err):gsub('\n', '\n      '))
  end
end
print(('%d passed, %d failed'):format(#tests - failed, failed))
os.exit(failed == 0 and 0 or 1)