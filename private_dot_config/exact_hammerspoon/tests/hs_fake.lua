-- Simulated Hammerspoon APIs for running init.lua outside Hammerspoon.
--
-- Only the behaviour the config relies on is modelled, following the
-- Hammerspoon 1.1.1 sources:
--   * Native objects keep their Lua callbacks in a registry-like table. When
--     Lua garbage-collects a timer, event tap or pathwatcher, its finalizer
--     stops it and drops the callback.
--   * An event tap callback that raises makes hs.eventtap drop the event.
--   * Callback errors inside timers and choosers are caught and logged by
--     Hammerspoon; they are recorded here as native errors.
--   * hs.chooser is a non-activating panel: while it is open it receives the
--     keyboard, but the frontmost application does not change. show() runs
--     the query callback; query(nil) clears the query without running it.
--     The default global callback refocuses the window that was frontmost
--     when the chooser opened.
--   * Every pasteboard write bumps the change count once; setContents clears
--     the pasteboard before writing. A write after another process has
--     changed the pasteboard since that clear is rejected (NSPasteboard
--     ownership), leaving the other process's data.
--   * Timers behave like NSTimer on the main run loop: while the run loop is
--     blocked (stall) none fire, and a late repeating timer fires once and
--     then keeps its original schedule.
--   * hs.chooser reports a result only after hiding its window; a choice is
--     a copy of the row, extra keys included.
-- Time is virtual and only moves in advance(). Nothing here proves native
-- object lifetime, focus behaviour or real pasteboard timing.

local M = {}

M.WEZTERM = 'com.github.wez.wezterm'
M.HYPER = { 'cmd', 'ctrl', 'alt', 'shift' }

local KEYCODES = { c = 8, h = 4, l = 37, v = 9 }
local LOG_LEVELS = { error = 1, warning = 2, info = 3, debug = 4, verbose = 5 }

local function us(seconds) return math.floor(seconds * 1e6 + 0.5) end

local function weakKeys() return setmetatable({}, { __mode = 'k' }) end

local Sim = {}
Sim.__index = Sim

function Sim:ref(fn)
  self.lastRef = self.lastRef + 1
  self.refs[self.lastRef] = fn
  return self.lastRef
end

function Sim:unref(ref)
  if ref then self.refs[ref] = nil end
end

function Sim:nextSeq()
  self.seq = self.seq + 1
  return self.seq
end

-- A Lua error that escaped a callback into (simulated) native code.
function Sim:nativeError(where, err)
  self.nativeErrors[#self.nativeErrors + 1] = where .. ': ' .. tostring(err)
end

-- Calls a registered callback the way LuaSkin's protected call does.
function Sim:callRef(where, ref, ...)
  local fn = ref and self.refs[ref]
  if not fn then return false end
  local ok, res = pcall(fn, ...)
  if not ok then
    self:nativeError(where, res)
    return false, res
  end
  return true, res
end

function Sim:maybeThrow(name)
  if self.throwOnce[name] then
    self.throwOnce[name] = nil
    error('injected failure in ' .. name, 2)
  end
end

function Sim:throwNext(name) self.throwOnce[name] = true end

function Sim:log(line) self.logs[#self.logs + 1] = line end

function Sim:logText() return table.concat(self.logs, '\n') end

-- Timeline ------------------------------------------------------------------

function Sim:after(seconds, fn)
  self.actions[#self.actions + 1] =
    { at = self.now + us(seconds), seq = self:nextSeq(), fn = fn }
end

function Sim:nextDue(limit, actionsOnly)
  local best
  local function consider(at, seq, item)
    if at > limit then return end
    if not best or at < best.at or (at == best.at and seq < best.seq) then
      best = { at = at, seq = seq, item = item }
    end
  end
  if not actionsOnly then
    for timer in pairs(self.timers) do
      if timer.isRunning then consider(timer.nextFire, timer.seq, timer) end
    end
  end
  for _, action in ipairs(self.actions) do
    consider(action.at, action.seq, action)
  end
  return best
end

-- Like NSTimer: a timer that is late fires once, then resumes its schedule
-- at the next firing time after now.
function Sim:fireTimer(timer)
  if timer.repeats then
    local step = math.max(timer.interval, 1)
    repeat
      timer.nextFire = timer.nextFire + step
    until timer.nextFire > self.now
    timer.seq = self:nextSeq()
  else
    timer.isRunning = false
  end
  local ok = self:callRef('hs.timer callback', timer.ref)
  if not ok and not timer.continueOnError then timer.isRunning = false end
end

function Sim:run(limit, actionsOnly)
  while true do
    local due = self:nextDue(limit, actionsOnly)
    if not due then break end
    -- An overdue timer (after stall) fires now, not in the past.
    self.now = math.max(self.now, due.at)
    if due.item.fn then
      for i, action in ipairs(self.actions) do
        if action == due.item then
          table.remove(self.actions, i)
          break
        end
      end
      due.item.fn()
    else
      self:fireTimer(due.item)
    end
  end
  self.now = limit
end

function Sim:advance(seconds) self:run(self.now + us(seconds), false) end

-- Blocks Hammerspoon's run loop for `seconds`: other processes (scheduled
-- actions) still run, but no timer fires. Timers that came due fire late,
-- once each, on the next advance().
function Sim:stall(seconds) self:run(self.now + us(seconds), true) end

-- Full collection cycles; finalizers that release further objects need more
-- than one.
function Sim:collect()
  for _ = 1, 4 do
    collectgarbage('collect')
  end
end

-- Pasteboard ----------------------------------------------------------------

function Sim:pbWrite(text, kind)
  self.pb.count = self.pb.count + 1
  self.pb.kind = kind or 'text'
  self.pb.text = (self.pb.kind == 'text') and text or nil
end

-- Applications and windows --------------------------------------------------

local App = {}
App.__index = App
function App:name() return self.appName end
function App:bundleID() return self.bundle end
function App:pid() return self.processID end
function App:allWindows() return self.windows or {} end

local Window = {}
Window.__index = Window
function Window:application() return self.app end
function Window:id() return self.windowId end
function Window:focus()
  self.sim.front = self.app
  self.sim.focusLog[#self.sim.focusLog + 1] = self
  return self
end

M.Window = Window

function Sim:newApp(name, bundle, pid)
  local app = setmetatable({
    appName = name,
    bundle = bundle,
    processID = pid,
    selection = nil, -- text the app copies on cmd-c; nil copies nothing
    kind = 'text',
    latency = 0.005, -- seconds between cmd-c and the pasteboard write
  }, App)
  self.nextWindowId = (self.nextWindowId or 0) + 1
  app.window = setmetatable({
    sim = self,
    app = app,
    title = name,
    windowId = self.nextWindowId,
    valid = true,
  }, Window)
  app.windows = { app.window }
  return app
end

function Sim:closeApp(app)
  for i, a in ipairs(self.appList) do
    if a == app then
      table.remove(self.appList, i)
      break
    end
  end
  if app.windows then
    for _, w in ipairs(app.windows) do
      w.valid = false
      w.app = nil
    end
    app.windows = {}
  end
  -- Also handle legacy single-window case
  if app.window then
    app.window.valid = false
    app.window.app = nil
  end
  if self.front == app then self.front = nil end
end

function Sim:addWindowToApp(window, app)
  if not app.windows then app.windows = {} end
  app.windows[#app.windows + 1] = window
end

function Sim:closeWindow(window)
  local app = window:application()
  if app and app.windows then
    for i, w in ipairs(app.windows) do
      if w == window then
        table.remove(app.windows, i)
        break
      end
    end
  end
  window.app = nil
  window.valid = false
end

function Sim:switchTo(app) self.front = app end

-- Keyboard ------------------------------------------------------------------

local Event = {}
Event.__index = Event
function Event:getFlags()
  local flags = {}
  for k, v in pairs(self.flags) do
    flags[k] = v
  end
  return flags
end
function Event:getKeyCode() return self.keyCode end
function Event:getProperty(prop) return self.props[prop] or 0 end

local function isCopyCombo(flags, key)
  return key == 'c' and flags.cmd and not (flags.ctrl or flags.alt or flags.fn)
end

-- Presses a key: first checks hotkey bindings, then event taps,
-- then the keyboard focus (the open chooser, otherwise the frontmost app).
-- Returns whether the event reached that focus.
function Sim:press(mods, key, opts)
  opts = opts or {}

  -- Check hotkey bindings first (they consume the keystroke).
  if self:invokeHotkey(mods, key) then return false end

  local flags = {}
  for _, m in ipairs(mods) do
    flags[m] = true
  end
  local props = self.hs.eventtap.event.properties
  local event = setmetatable({
    flags = flags,
    keyCode = KEYCODES[key],
    props = {
      [props.keyboardEventAutorepeat] = opts.autorepeat and 1 or 0,
      [props.eventTargetUnixProcessID] = opts.targetPid or 0,
    },
  }, Event)

  local dropped = false
  -- Secure Input withholds keystrokes from event taps.
  if not self.secureInput then
    for tap in pairs(self.taps) do
      if tap.enabled then
        local ok, res = self:callRef('hs.eventtap callback', tap.ref, event)
        if not ok or res == true then dropped = true end
      end
    end
  end
  if dropped then return false end

  local chooser = self:liveChooser()
  if chooser and chooser.visible then
    if isCopyCombo(flags, key) and self.chooserFieldSelection then
      self:pbWrite(self.chooserFieldSelection)
    end
    return true
  end
  local app = self.front
  if app and isCopyCombo(flags, key) and app.selection ~= nil then
    local text, kind = app.selection, app.kind
    self:after(app.latency, function() self:pbWrite(text, kind) end)
  end
  return true
end

function Sim:pressHotkey(mods, key)
  return self:invokeHotkey(mods, key)
end

-- Fires a hotkey callback directly, without going through press().
function Sim:invokeHotkey(mods, key)
  local wanted = table.concat(mods, '+') .. '+' .. key
  for _, hotkey in ipairs(self.hotkeys) do
    if table.concat(hotkey.mods, '+') .. '+' .. hotkey.key == wanted then
      hotkey.fn()
      return true
    end
  end
  return false
end

function Sim:disableTaps()
  for tap in pairs(self.taps) do
    tap.enabled = false
  end
end

function Sim:enabledTapCount()
  local n = 0
  for tap in pairs(self.taps) do
    if tap.enabled then n = n + 1 end
  end
  return n
end

-- Chooser -------------------------------------------------------------------

function Sim:liveChooser()
  for chooser in pairs(self.choosers) do
    return chooser
  end
end

function Sim:chooserRows()
  local chooser = self:liveChooser()
  return chooser and chooser.rows or {}
end

local function copyRow(row)
  local out = {}
  for k, v in pairs(row) do
    out[k] = v
  end
  return out
end

-- Mirrors HSChooser tableView:didClickedRow:.
function Sim:clickRow(index)
  local chooser = assert(self:liveChooser(), 'no chooser')
  assert(chooser.visible, 'chooser is not open')
  local row = chooser.rows[index]
  assert(row, 'no chooser row ' .. tostring(index))
  chooser.hasChosen = true
  chooser:hide()
  self:callRef('hs.chooser completion', chooser.completionRef, copyRow(row))
end

function Sim:choose(text)
  for i, row in ipairs(self:chooserRows()) do
    if row.text == text then return self:clickRow(i) end
  end
  error('no chooser row named ' .. text, 2)
end

-- Enter picks the selected row, which stays at the first row here.
function Sim:pressEnter() self:clickRow(1) end

-- Typing into the query field runs the query callback (controlTextDidChange).
function Sim:typeQuery(query)
  local chooser = assert(self:liveChooser(), 'no chooser')
  chooser.queryText = query
  self:callRef('hs.chooser query callback', chooser.queryRef, query)
end

-- Escape resigns key; losing key without a choice cancels (HSChooser cancel:).
function Sim:escape()
  local chooser = assert(self:liveChooser(), 'no chooser')
  assert(chooser.visible, 'chooser is not open')
  if chooser.hasChosen then return end
  chooser:hide()
  self:callRef('hs.chooser completion', chooser.completionRef, nil)
end

-- Delivers a completion result directly, as a late or duplicate callback.
-- With `hideFirst`, follows hs.chooser's own order: hide, then report.
function Sim:deliverChooserResult(choice, opts)
  local chooser = assert(self:liveChooser(), 'no chooser')
  if opts and opts.hideFirst then chooser:hide() end
  self:callRef('hs.chooser completion', chooser.completionRef, choice)
end

-- A copy of the current row named `text`, as hs.chooser would report it.
function Sim:savedRow(text)
  for _, row in ipairs(self:chooserRows()) do
    if row.text == text then return copyRow(row) end
  end
  error('no chooser row named ' .. text, 2)
end

-- Config watcher ------------------------------------------------------------

function Sim:touchConfig()
  for watcher in pairs(self.watchers) do
    if watcher.running then
      self:callRef(
        'hs.pathwatcher callback',
        watcher.ref,
        { watcher.path .. '/init.lua' }
      )
    end
  end
end

-- hs ------------------------------------------------------------------------

local function buildHs(sim)
  local hs = {}

  hs.processInfo = { processID = 999 }
  hs.reload = function() sim.reloads = sim.reloads + 1 end
  hs.alert = { show = function(msg) sim.alerts[#sim.alerts + 1] = msg end }

  hs.logger = {
    new = function(id, level)
      local threshold = LOG_LEVELS[level or 'warning'] or 2
      local logger = {}
      local function emit(lvl, msg)
        if LOG_LEVELS[lvl] <= threshold then
          sim:log(('[%s] %s: %s'):format(id, lvl, msg))
        end
      end
      local function plain(lvl)
        return function(...)
          local parts = {}
          for i = 1, select('#', ...) do
            parts[#parts + 1] = tostring((select(i, ...)))
          end
          emit(lvl, table.concat(parts, ' '))
        end
      end
      local function formatted(lvl)
        return function(fmt, ...) emit(lvl, fmt:format(...)) end
      end
      logger.e, logger.ef = plain('error'), formatted('error')
      logger.w, logger.wf = plain('warning'), formatted('warning')
      logger.i, logger.f = plain('info'), formatted('info')
      logger.d, logger.df = plain('debug'), formatted('debug')
      logger.v, logger.vf = plain('verbose'), formatted('verbose')
      return logger
    end,
  }

  -- hs.timer
  local Timer = {}
  Timer.__index = Timer
  Timer.__gc = function(timer)
    timer.isRunning = false
    sim:unref(timer.ref)
    timer.ref = nil
    sim.finalized[#sim.finalized + 1] = 'timer'
  end
  function Timer:start()
    self.isRunning = true
    self.nextFire = sim.now + self.interval
    self.seq = sim:nextSeq()
    return self
  end
  function Timer:stop()
    self.isRunning = false
    return self
  end
  function Timer:running() return self.isRunning end

  local function newTimer(seconds, fn, repeats, continueOnError)
    local timer = setmetatable({
      interval = us(seconds),
      ref = sim:ref(fn),
      repeats = repeats,
      continueOnError = continueOnError,
      isRunning = false,
    }, Timer)
    sim.timers[timer] = true
    return timer
  end

  hs.timer = {
    new = function(seconds, fn, continueOnError)
      return newTimer(seconds, fn, true, continueOnError)
    end,
    doAfter = function(seconds, fn)
      return newTimer(seconds, fn, false, false):start()
    end,
    doEvery = function(seconds, fn)
      return newTimer(seconds, fn, true, false):start()
    end,
    absoluteTime = function() return sim.now * 1000 end,
    secondsSinceEpoch = function() return sim.now / 1e6 end,
    usleep = function() end,
  }

  -- hs.eventtap
  local Tap = {}
  Tap.__index = Tap
  Tap.__gc = function(tap)
    tap.enabled = false
    sim:unref(tap.ref)
    tap.ref = nil
    sim.finalized[#sim.finalized + 1] = 'eventtap'
  end
  function Tap:start()
    sim.tapStarts = sim.tapStarts + 1
    if not self.enabled then
      if sim.accessibilityDenied then
        sim.nativeLog[#sim.nativeLog + 1] = 'Unable to create eventtap'
      else
        self.enabled = true
      end
    end
    return self
  end
  function Tap:stop()
    self.enabled = false
    return self
  end
  function Tap:isEnabled() return self.enabled end

  hs.eventtap = {
    new = function(types, fn)
      local tap =
        setmetatable({ types = types, ref = sim:ref(fn), enabled = false }, Tap)
      sim.taps[tap] = true
      return tap
    end,
    keyStroke = function(mods, key, delay, app)
      sim.keyStrokes[#sim.keyStrokes + 1] = {
        mods = table.concat(mods, '+'),
        key = key,
        app = app,
        generation = sim.pb.count,
      }
    end,
    isSecureInputEnabled = function() return sim.secureInput end,
    checkKeyboardModifiers = function()
      local held = sim.heldModifiers or {}
      return {
        cmd = held.cmd or false,
        alt = held.alt or false,
        ctrl = held.ctrl or false,
        shift = held.shift or false,
        fn = held.fn or false,
      }
    end,
    event = {
      types = { keyDown = 10, keyUp = 11 },
      properties = {
        keyboardEventAutorepeat = 8,
        eventTargetUnixProcessID = 40,
      },
    },
  }

  hs.hotkey = {
    bind = function(mods, key, fn)
      if sim.hotkeyBindFails then return nil end
      -- hs.hotkey keeps enabled hotkeys in its own module table.
      local hotkey = { mods = mods, key = key, fn = fn }
      sim.hotkeys[#sim.hotkeys + 1] = hotkey
      return hotkey
    end,
  }

  -- hs.pathwatcher
  local Watcher = {}
  Watcher.__index = Watcher
  Watcher.__gc = function(watcher)
    watcher.running = false
    sim:unref(watcher.ref)
    watcher.ref = nil
    sim.finalized[#sim.finalized + 1] = 'pathwatcher'
  end
  function Watcher:start()
    self.running = true
    return self
  end
  function Watcher:stop()
    self.running = false
    return self
  end

  hs.pathwatcher = {
    new = function(path, fn)
      local watcher = setmetatable(
        { path = path, ref = sim:ref(fn), running = false },
        Watcher
      )
      sim.watchers[watcher] = true
      return watcher
    end,
  }

  hs.pasteboard = {
    changeCount = function()
      sim:maybeThrow('pasteboard.changeCount')
      return sim.pb.count
    end,
    getContents = function()
      sim:maybeThrow('pasteboard.getContents')
      return sim.pb.text
    end,
    setContents = function(contents)
      sim:maybeThrow('pasteboard.setContents')
      sim.pb.count = sim.pb.count + 1 -- clearContents
      sim.pb.kind, sim.pb.text = 'empty', nil
      local owned = sim.pb.count
      -- Another process writing after clearContents takes ownership: the
      -- write is rejected and its data stays.
      local interloper = sim.duringNextWrite
      sim.duringNextWrite = nil
      if interloper then interloper() end
      if sim.pb.count ~= owned then return false end
      if sim.failWrites > 0 then
        sim.failWrites = sim.failWrites - 1
        sim.pb.kind, sim.pb.text = 'empty', nil
        return false
      end
      sim.pb.kind, sim.pb.text = 'text', tostring(contents)
      return true
    end,
  }
  hs.pasteboard.readString = hs.pasteboard.getContents

  hs.application = {
    frontmostApplication = function()
      sim:maybeThrow('application.frontmostApplication')
      return sim.front
    end,
    runningApplications = function()
      sim:maybeThrow('application.runningApplications')
      local apps = {}
      for _, a in ipairs(sim.appList) do
        apps[#apps + 1] = a
      end
      return apps
    end,
    applicationForPID = function(pid)
      for _, a in ipairs(sim.appList) do
        if a:pid() == pid then return a end
      end
      return nil
    end,
  }

  hs.window = {
    frontmostWindow = function() return sim.front and sim.front.window end,
    focusedWindow = function()
      if #sim.focusLog > 0 then return sim.focusLog[#sim.focusLog] end
      return sim.front and sim.front.window
    end,
  }

  -- hs.chooser
  local Chooser = {}
  Chooser.__index = Chooser
  function Chooser:choices(rows)
    if rows == nil then return self.rows end
    self.rows = rows
    return self
  end
  function Chooser:query(...)
    if select('#', ...) == 0 then return self.queryText end
    self.queryText = (...) or ''
    return self
  end
  function Chooser:queryChangedCallback(fn)
    sim:unref(self.queryRef)
    self.queryRef = fn and sim:ref(fn)
    return self
  end
  function Chooser:showCallback(fn)
    self.showFn = fn
    return self
  end
  function Chooser:hideCallback(fn)
    self.hideFn = fn
    return self
  end
  function Chooser:placeholderText(text)
    self.placeholder = text
    return self
  end
  function Chooser:isVisible() return self.visible end
  function Chooser:show()
    self.hasChosen = false
    local globalFn = hs.chooser.globalCallback
    if globalFn then
      local ok, err = pcall(globalFn, self, 'willOpen')
      if not ok then sim:nativeError('hs.chooser.globalCallback', err) end
    end
    self.visible = true
    sim.showCount = sim.showCount + 1
    self:runQueryCallback()
    if self.showFn then pcall(self.showFn) end
    return self
  end
  function Chooser:runQueryCallback()
    sim:callRef('hs.chooser query callback', self.queryRef, self.queryText)
  end
  function Chooser:hide()
    self.visible = false
    local globalFn = hs.chooser.globalCallback
    if globalFn then
      local ok, err = pcall(globalFn, self, 'didClose')
      if not ok then sim:nativeError('hs.chooser.globalCallback', err) end
    end
    if self.hideFn then pcall(self.hideFn) end
    return self
  end

  hs.chooser = { _lastFocused = {} }
  -- Same logic as the 1.1.1 default global callback.
  hs.chooser._defaultGlobalCallback = function(chooser, state)
    if state == 'willOpen' then
      hs.chooser._lastFocused[chooser] = hs.window.frontmostWindow()
    elseif state == 'didClose' then
      local window = hs.chooser._lastFocused[chooser]
      if window then
        window:focus()
        hs.chooser._lastFocused[chooser] = nil
      end
    end
  end
  hs.chooser.globalCallback = hs.chooser._defaultGlobalCallback
  hs.chooser.new = function(fn)
    local chooser = setmetatable({
      completionRef = sim:ref(fn),
      rows = {},
      queryText = '',
      visible = false,
      hasChosen = false,
    }, Chooser)
    sim.choosers[chooser] = true
    return chooser
  end

  return hs
end

function M.new(opts)
  opts = opts or {}
  local sim = setmetatable({
    now = 0, -- microseconds
    seq = 0,
    refs = {}, -- the "registry": strong references to callbacks
    lastRef = 0,
    timers = weakKeys(),
    taps = weakKeys(),
    watchers = weakKeys(),
    choosers = weakKeys(),
    actions = {},
    hotkeys = {},
    keyStrokes = {},
    alerts = {},
    logs = {},
    nativeErrors = {},
    nativeLog = {},
    finalized = {},
    focusLog = {},
    throwOnce = {},
    reloads = 0,
    showCount = 0,
    tapStarts = 0,
    failWrites = 0,
    secureInput = false,
    accessibilityDenied = false,
    chooserFieldSelection = nil,
    heldModifiers = {},
    hotkeyBindFails = opts.hotkeyBindFails or false,
    appList = {},
    pb = {
      count = 1000,
      kind = 'text',
      text = opts.clipboard or 'older clipboard text',
    },
  }, Sim)
  sim.apps = {
    wezterm = sim:newApp('WezTerm', M.WEZTERM, 4001),
    brave = sim:newApp('Brave Browser', 'com.brave.Browser', 4002),
  }
  -- Populate appList from the apps table.
  for _, app in pairs(sim.apps) do
    sim.appList[#sim.appList + 1] = app
  end
  sim.front = sim.apps.wezterm
  sim.hs = buildHs(sim)
  return sim
end

-- Loads a config file into a fresh environment whose globals stand in for
-- Hammerspoon's, so `_G` in the config is this environment.
function M.load(path, opts)
  local sim = M.new(opts)
  local env = setmetatable({ hs = sim.hs }, { __index = _G })
  env._G = env
  env.print = function(...)
    local parts = {}
    for i = 1, select('#', ...) do
      parts[#parts + 1] = tostring((select(i, ...)))
    end
    sim:log('[print] ' .. table.concat(parts, ' '))
  end
  sim.env = env
  local chunk = assert(loadfile(path, 't', env))
  chunk()
  return sim
end

M.Window = Window

return M
