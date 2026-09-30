-- Behaviour tests for the WezTerm ⌘C → fenced code block chooser and the
-- runtime objects in ../init.lua, run against simulated Hammerspoon APIs
-- (hs_fake.lua) with a virtual clock. Needs Lua 5.4+ (table finalizers).
--
--   lua private_dot_config/exact_hammerspoon/tests/copy_fence_test.lua [init]
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

local function fence(lang, text) return '```' .. lang .. '\n' .. text .. '\n```' end

-- A freshly loaded config with WezTerm frontmost.
local function start(opts)
  local sim = fake.load(target, opts)
  sims[#sims + 1] = sim
  return sim
end

-- ⌘C in WezTerm with `text` selected, then enough time for the copy to land.
local function copyInWezTerm(sim, text, mods)
  sim.apps.wezterm.selection = text
  sim:switchTo(sim.apps.wezterm)
  check(sim:press(mods or { 'cmd' }, 'c'), 'the key event must pass through')
  sim:advance(0.3)
end

local function chooserOpen(sim)
  local chooser = sim:liveChooser()
  return chooser ~= nil and chooser.visible
end

-- 1. Successful copies ------------------------------------------------------

test('cmd-c offers the chooser and formats with a preset tag', function()
  local sim = start()
  copyInWezTerm(sim, 'print(1)')
  eq(sim.showCount, 1, 'chooser presentations')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'print(1)'), 'pasteboard')
end)

test('cmd-shift-c works the same, and "No language tag" has no tag', function()
  local sim = start()
  copyInWezTerm(sim, 'ls -la', { 'cmd', 'shift' })
  eq(sim.showCount, 1, 'chooser presentations')
  sim:choose('No language tag')
  eq(sim.pb.text, fence('', 'ls -la'), 'pasteboard')
end)

test('a typed custom tag is used and the next query starts empty', function()
  local sim = start()
  copyInWezTerm(sim, 'IO.puts(1)')
  sim:typeQuery('elixir')
  eq(sim:chooserRows()[1].text, 'elixir', 'custom row first')
  sim:pressEnter()
  eq(sim.pb.text, fence('elixir', 'IO.puts(1)'), 'pasteboard')

  copyInWezTerm(sim, 'x = 1')
  eq(sim:chooserRows()[1].text, 'No language tag', 'first row after reopen')
  sim:choose('python')
  eq(sim.pb.text, fence('python', 'x = 1'), 'pasteboard')
end)

test('whitespace in the copied text is preserved exactly', function()
  local sim = start()
  local text = '  indented\n\ttabbed  \n\n'
  copyInWezTerm(sim, text)
  sim:choose('sh')
  eq(sim.pb.text, fence('sh', text), 'pasteboard')
end)

-- 2. Same text, new pasteboard generation ------------------------------------

test('copying identical text twice is two separate requests', function()
  local sim = start()
  copyInWezTerm(sim, 'same')
  sim:choose('sh')
  copyInWezTerm(sim, 'same')
  eq(sim.showCount, 2, 'chooser presentations')
  sim:choose('sh')
  eq(sim.pb.text, fence('sh', 'same'), 'pasteboard (not wrapped twice)')
end)

-- 3. Pasteboard update timing and contents -----------------------------------

test('no pasteboard update: no chooser, old clipboard untouched', function()
  local sim = start({ clipboard = 'older text' })
  copyInWezTerm(sim, nil) -- nothing selected, WezTerm writes nothing
  sim:advance(1)
  eq(sim.showCount, 0, 'chooser presentations')
  eq(sim.pb.text, 'older text', 'pasteboard')
end)

test('an update that arrives late but within the timeout is used', function()
  local sim = start()
  sim.pb.kind, sim.pb.text = 'image', nil
  sim.apps.wezterm.latency = 0.3
  sim.apps.wezterm.selection = 'slow copy'
  sim:press({ 'cmd' }, 'c')
  sim:advance(0.25)
  eq(sim.showCount, 0, 'presentations before the write')
  sim:advance(0.2)
  eq(sim.showCount, 1, 'presentations after the write')
  sim:choose('bash')
  eq(sim.pb.text, fence('bash', 'slow copy'), 'pasteboard')
end)

test('an update after the timeout is not offered or formatted', function()
  local sim = start({ clipboard = 'older text' })
  sim.apps.wezterm.latency = 0.8
  sim.apps.wezterm.selection = 'too late'
  sim:press({ 'cmd' }, 'c')
  sim:advance(1.5)
  eq(sim.showCount, 0, 'chooser presentations')
  eq(sim.pb.text, 'too late', 'pasteboard keeps the raw copy')
end)

-- The deadline is 500 ms after the key press; polls run every 20 ms, so the
-- 480 ms poll is the last one that can accept a change.
test('a change seen by the last poll before the deadline is used', function()
  local sim = start()
  sim.apps.wezterm.latency = 0.47
  sim.apps.wezterm.selection = 'just in time'
  sim:press({ 'cmd' }, 'c')
  sim:advance(0.49)
  eq(sim.showCount, 1, 'chooser presentations')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'just in time'), 'pasteboard')
end)

test('the poll at the deadline cancels even with a change waiting', function()
  local sim = start()
  sim.apps.wezterm.latency = 0.49
  sim.apps.wezterm.selection = 'at the boundary'
  sim:press({ 'cmd' }, 'c')
  sim:advance(1)
  eq(sim.showCount, 0, 'chooser presentations')
  eq(sim.pb.text, 'at the boundary', 'pasteboard keeps the raw copy')
end)

test('a poll delayed past the deadline cancels instead of accepting', function()
  local sim = start({ clipboard = 'older text' })
  sim.apps.wezterm.selection = nil -- WezTerm writes nothing
  sim:press({ 'cmd' }, 'c')
  sim:advance(0.48) -- the 480 ms poll sees no change
  sim:stall(0.12) -- run loop blocked: polls due from 500 ms wait
  sim:pbWrite('late change') -- one change, at 600 ms
  local count = sim.pb.count
  sim:advance(0) -- the overdue poll runs once, at 600 ms
  eq(sim.showCount, 0, 'chooser presentations')
  check(sim:logText():find('timed out', 1, true), 'cancellation logged')
  sim:advance(1)
  eq(sim.showCount, 0, 'chooser presentations later')
  eq(sim.pb.text, 'late change', 'pasteboard')
  eq(sim.pb.count, count, 'pasteboard change count')
end)

test('an empty copy opens no chooser', function()
  local sim = start()
  copyInWezTerm(sim, '')
  eq(sim.showCount, 0, 'chooser presentations')
  eq(sim.pb.text, '', 'pasteboard')
end)

test('a non-text pasteboard change opens no chooser', function()
  local sim = start()
  sim.apps.wezterm.kind = 'image'
  copyInWezTerm(sim, 'ignored')
  eq(sim.showCount, 0, 'chooser presentations')
  eq(sim.pb.kind, 'image', 'pasteboard kind')
end)

-- 4. App switches ------------------------------------------------------------

test('copy in WezTerm, then switch apps before the write lands', function()
  local sim = start()
  local brave = sim.apps.brave
  sim.apps.wezterm.latency = 0.03
  sim.apps.wezterm.selection = 'from terminal'
  sim:press({ 'cmd' }, 'c')
  sim:after(0.01, function() sim:switchTo(brave) end)
  sim:advance(0.3)
  eq(sim.showCount, 1, 'chooser presentations')
  sim:choose('go')
  eq(sim.pb.text, fence('go', 'from terminal'), 'pasteboard')
  eq(sim.focusLog[#sim.focusLog], brave.window, 'window focused after close')
  eq(sim.front, brave, 'frontmost app after close')
end)

test('copy elsewhere, then switch into WezTerm: no chooser', function()
  local sim = start()
  sim.apps.brave.selection = 'web text'
  sim:switchTo(sim.apps.brave)
  sim:press({ 'cmd' }, 'c')
  sim:after(0.01, function() sim:switchTo(sim.apps.wezterm) end)
  sim:advance(1)
  eq(sim.showCount, 0, 'chooser presentations')
  eq(sim.pb.text, 'web text', 'pasteboard')
end)

test('a copy in another app while waiting cancels the request', function()
  local sim = start({ clipboard = 'older text' })
  sim.apps.wezterm.selection = nil -- WezTerm copies nothing
  sim.apps.brave.selection = 'web text'
  sim:press({ 'cmd' }, 'c')
  sim:after(0.1, function()
    sim:switchTo(sim.apps.brave)
    sim:press({ 'cmd' }, 'c')
  end)
  sim:advance(1)
  eq(sim.showCount, 0, 'chooser presentations')
  eq(sim.pb.text, 'web text', 'pasteboard')
end)

test('two pasteboard changes before the check are ambiguous', function()
  local sim = start()
  sim.apps.wezterm.latency = 0.004
  sim.apps.wezterm.selection = 'terminal text'
  sim:press({ 'cmd' }, 'c')
  sim:after(0.008, function() sim:pbWrite('other writer') end)
  sim:advance(1)
  eq(sim.showCount, 0, 'chooser presentations')
  eq(sim.pb.text, 'other writer', 'pasteboard')
end)

-- 5. Pasteboard changed before confirmation -----------------------------------

test('a newer pasteboard write before confirming is preserved', function()
  local sim = start()
  copyInWezTerm(sim, 'terminal text')
  sim:pbWrite('newer data') -- another app, while the chooser is open
  sim:choose('lua')
  eq(sim.pb.text, 'newer data', 'pasteboard')
end)

-- 6. Rapid, repeated and stale input ------------------------------------------

test('rapid copies: only the newest request opens the chooser', function()
  local sim = start()
  local wez = sim.apps.wezterm
  wez.latency = 0.004
  wez.selection = 'first'
  sim:press({ 'cmd' }, 'c')
  sim:after(0.006, function()
    wez.selection = 'second'
    sim:press({ 'cmd' }, 'c')
  end)
  sim:advance(0.5)
  eq(sim.showCount, 1, 'chooser presentations')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'second'), 'pasteboard')
end)

test('a superseded request cannot open the chooser or time out', function()
  local sim = start({ clipboard = 'older text' })
  local wez = sim.apps.wezterm
  wez.selection = nil -- first ⌘C copies nothing
  sim:press({ 'cmd' }, 'c')
  sim:after(0.3, function()
    wez.selection = 'later'
    sim:press({ 'cmd' }, 'c')
  end)
  sim:advance(1)
  eq(sim.showCount, 1, 'chooser presentations')
  check(chooserOpen(sim), 'chooser for the second request must stay open')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'later'), 'pasteboard')
end)

test('cmd-c while the chooser is open belongs to the chooser', function()
  local sim = start()
  copyInWezTerm(sim, 'terminal text')
  sim.chooserFieldSelection = 'lu' -- text selected in the query field
  sim:press({ 'cmd' }, 'c')
  sim:advance(0.3)
  eq(sim.showCount, 1, 'chooser presentations')
  check(chooserOpen(sim), 'chooser must stay open')
  sim:choose('lua')
  eq(sim.pb.text, 'lu', 'pasteboard keeps the chooser copy')
end)

test('auto-repeat does not start a request', function()
  local sim = start()
  sim.apps.wezterm.selection = 'held'
  sim:press({ 'cmd' }, 'c', { autorepeat = true })
  sim:advance(0.5)
  eq(sim.showCount, 0, 'chooser presentations')
end)

test('extra modifiers do not start a request', function()
  local sim = start()
  sim.apps.wezterm.selection = 'text'
  for _, mods in ipairs({
    { 'cmd', 'ctrl' },
    { 'cmd', 'alt' },
    { 'cmd', 'fn' },
    fake.HYPER,
    { 'ctrl' },
    {},
  }) do
    check(sim:press(mods, 'c'), 'key event must pass through')
    -- A request would claim this unrelated write as its copy.
    sim:after(0.05, function() sim:pbWrite('background write') end)
    sim:advance(0.6)
  end
  eq(sim.showCount, 0, 'chooser presentations')
end)

test('a late or duplicate chooser result is ignored', function()
  local sim = start()
  copyInWezTerm(sim, 'once')
  sim:choose('lua')
  sim:deliverChooserResult({ text = 'go', lang = 'go' })
  eq(sim.pb.text, fence('lua', 'once'), 'pasteboard')
end)

test('a stale chooser result cannot touch a newer waiting request', function()
  local sim = start()
  copyInWezTerm(sim, 'old request')
  sim:escape()
  sim.apps.wezterm.latency = 0.2
  sim.apps.wezterm.selection = 'new request'
  sim:press({ 'cmd' }, 'c')
  sim:advance(0.05)
  sim:deliverChooserResult({ text = 'go', lang = 'go' })
  sim:deliverChooserResult(nil) -- a cancellation while the request waits
  sim:advance(0.3)
  eq(sim.showCount, 2, 'chooser presentations')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'new request'), 'pasteboard')
end)

-- hs.chooser 1.1.1 reports results synchronously, for rows of the chooser
-- that is showing, so these late deliveries are synthetic: they check that a
-- result is bound to its own request.
local function savedResultsFromDismissedRequest(sim)
  copyInWezTerm(sim, 'request A')
  local preset = sim:savedRow('lua')
  sim:typeQuery('elixir')
  local custom = sim:savedRow('elixir')
  sim:escape()
  eq(sim.pb.text, 'request A', 'pasteboard after dismissing A')
  return preset, custom
end

test("saved results from request A cannot touch B's open chooser", function()
  local sim = start()
  local preset, custom = savedResultsFromDismissedRequest(sim)
  copyInWezTerm(sim, 'request B')
  check(chooserOpen(sim), "B's chooser must be open")
  sim:deliverChooserResult(preset)
  sim:deliverChooserResult(custom)
  sim:deliverChooserResult(nil) -- a cancellation while B's window is open
  check(chooserOpen(sim), "B's chooser must stay open")
  eq(sim.pb.text, 'request B', 'pasteboard while B is open')
  sim:choose('go')
  eq(sim.pb.text, fence('go', 'request B'), 'pasteboard')
end)

test("A's result in native order (hide, then report) leaves B live", function()
  local sim = start()
  local preset, custom = savedResultsFromDismissedRequest(sim)
  for _, saved in ipairs({ preset, custom }) do
    copyInWezTerm(sim, 'request B')
    sim:deliverChooserResult(saved, { hideFirst = true })
    eq(sim.pb.text, 'request B', 'pasteboard')
    local state = sim.env.dotfiles.wezTermCopy
    eq(state.active and state.active.phase, 'choosing', 'B still live')
    eq(state.chooserFor, state.active.id, 'chooser still bound to B')
  end
  copyInWezTerm(sim, 'request C')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'request C'), 'pasteboard')
end)

-- 7. Escape and errors -------------------------------------------------------

test('Escape leaves the pasteboard untouched; the next copy works', function()
  local sim = start()
  copyInWezTerm(sim, 'keep me')
  local count = sim.pb.count
  sim:escape()
  eq(sim.pb.text, 'keep me', 'pasteboard')
  eq(sim.pb.count, count, 'pasteboard change count')
  copyInWezTerm(sim, 'next')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'next'), 'pasteboard')
end)

test('an error while reading the pasteboard is contained', function()
  local sim = start()
  sim:throwNext('pasteboard.getContents')
  copyInWezTerm(sim, 'first')
  eq(sim.showCount, 0, 'chooser presentations')
  copyInWezTerm(sim, 'second')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'second'), 'pasteboard')
end)

test('an error in the key handler still passes the key through', function()
  local sim = start()
  sim:throwNext('application.frontmostApplication')
  copyInWezTerm(sim, 'copied anyway')
  eq(sim.pb.text, 'copied anyway', 'WezTerm still copied')
  sim:advance(1)
  copyInWezTerm(sim, 'second')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'second'), 'pasteboard')
end)

test('an error while confirming is contained', function()
  local sim = start()
  copyInWezTerm(sim, 'first')
  sim:throwNext('pasteboard.setContents')
  sim:choose('lua')
  eq(sim.pb.text, 'first', 'pasteboard')
  copyInWezTerm(sim, 'second')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'second'), 'pasteboard')
end)

-- 8. Failed pasteboard writes ------------------------------------------------

test('a failed write is reported and the copy put back', function()
  local sim = start()
  copyInWezTerm(sim, 'first')
  sim.failWrites = 1
  sim:choose('lua')
  check(
    sim:logText():find('write failed', 1, true),
    'a write failure must be logged'
  )
  eq(sim.pb.text, 'first', 'pasteboard')
  copyInWezTerm(sim, 'second')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'second'), 'pasteboard')
end)

-- Another app writes between hs.pasteboard's clearContents and setString, so
-- the formatting write fails and that app now owns the pasteboard.
local function failWriteAfterOwnershipLoss(interloper)
  local sim = start()
  copyInWezTerm(sim, 'terminal text')
  sim.duringNextWrite = function() interloper(sim) end
  sim:choose('lua')
  check(
    sim:logText():find('write failed', 1, true),
    'a write failure must be logged'
  )
  return sim
end

test('newer text survives a failed formatting write', function()
  local count
  local sim = failWriteAfterOwnershipLoss(function(sim)
    sim:pbWrite('newer text')
    count = sim.pb.count
  end)
  eq(sim.pb.text, 'newer text', 'pasteboard')
  eq(sim.pb.count, count, 'pasteboard change count')
end)

test('newer non-text data survives a failed formatting write', function()
  local count
  local sim = failWriteAfterOwnershipLoss(function(sim)
    sim:pbWrite(nil, 'image')
    count = sim.pb.count
  end)
  eq(sim.pb.kind, 'image', 'pasteboard kind')
  eq(sim.pb.count, count, 'pasteboard change count')
  copyInWezTerm(sim, 'next')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'next'), 'the next copy still works')
end)

test('logs never contain pasteboard text', function()
  local secret = 'SENTINEL-pasteboard-7f3a'
  local sim = start({ clipboard = secret .. '-old' })
  copyInWezTerm(sim, secret .. '-1')
  sim:choose('lua')
  copyInWezTerm(sim, secret .. '-2')
  sim:escape()
  copyInWezTerm(sim, secret .. '-3')
  sim:pbWrite(secret .. '-4')
  sim:choose('lua')
  copyInWezTerm(sim, secret .. '-5')
  sim.failWrites = 2
  sim:choose('lua')
  sim:throwNext('pasteboard.setContents')
  copyInWezTerm(sim, secret .. '-6')
  sim:choose('lua')
  check(not sim:logText():find(secret, 1, true), 'pasteboard text logged')
end)

-- Runtime objects -------------------------------------------------------------

test('tap, config watcher and watchdog survive garbage collection', function()
  local sim = start()
  sim:collect()
  eq(sim:enabledTapCount(), 1, 'enabled event taps after collection')
  sim:touchConfig()
  eq(sim.reloads, 1, 'reloads after a config change')
  copyInWezTerm(sim, 'after gc')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'after gc'), 'pasteboard')
  sim:disableTaps()
  sim:collect()
  sim:advance(3)
  eq(sim:enabledTapCount(), 1, 'tap re-enabled by the watchdog')
end)

test('a pending request survives garbage collection', function()
  local sim = start()
  sim.apps.wezterm.latency = 0.03
  sim.apps.wezterm.selection = 'pending'
  sim:press({ 'cmd' }, 'c')
  sim:collect()
  sim:advance(0.3)
  eq(sim.showCount, 1, 'chooser presentations')
  sim:choose('lua')
  eq(sim.pb.text, fence('lua', 'pending'), 'pasteboard')
end)

test('failed tap restarts back off instead of retrying every tick', function()
  local sim = start()
  local initialStarts = sim.tapStarts
  sim.accessibilityDenied = true
  sim:disableTaps()
  sim:advance(60)
  local attempts = sim.tapStarts - initialStarts
  check(attempts >= 1, 'the watchdog must try to restart the tap')
  check(attempts <= 6, ('%d restart attempts in 60s'):format(attempts))
  sim.accessibilityDenied = false
  sim:advance(61)
  eq(sim:enabledTapCount(), 1, 'tap enabled once start succeeds')
end)

test('Secure Input does not cause tap restarts', function()
  local sim = start()
  local initialStarts = sim.tapStarts
  sim.secureInput = true
  sim:advance(5)
  copyInWezTerm(sim, 'during secure input')
  eq(sim.showCount, 0, 'no chooser while keys are withheld')
  eq(sim.tapStarts, initialStarts, 'tap start calls')
  sim.secureInput = false
  sim:advance(3)
  copyInWezTerm(sim, 'after')
  eq(sim.showCount, 1, 'chooser after Secure Input ends')
end)

test('Secure Input transitions are logged', function()
  local sim = start()
  sim.secureInput = true
  sim:advance(5)
  sim.secureInput = false
  sim:advance(3)
  local logText = sim:logText()
  check(logText:find('Secure Input on', 1, true), 'Secure Input on logged')
  check(logText:find('Secure Input off', 1, true), 'Secure Input off logged')
end)

-- Unchanged behaviour -----------------------------------------------------------

test('Hyper+H/L still send Hyper+Left/Right', function()
  local sim = start()
  check(sim:pressHotkey(fake.HYPER, 'h'), 'Hyper+H bound')
  check(sim:pressHotkey(fake.HYPER, 'l'), 'Hyper+L bound')
  eq(sim.keyStrokes[1].key, 'left', 'Hyper+H key')
  eq(sim.keyStrokes[2].key, 'right', 'Hyper+L key')
  eq(sim.keyStrokes[1].mods, table.concat(fake.HYPER, '+'), 'Hyper+H mods')
end)

test('the chooser global callback is left at its default', function()
  local sim = start()
  eq(
    sim.hs.chooser.globalCallback,
    sim.hs.chooser._defaultGlobalCallback,
    'hs.chooser.globalCallback'
  )
end)

-- Runner ----------------------------------------------------------------------

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
