-- Hammerspoon config
-- ~/.hammerspoon is a symlink -> ~/.config/hammerspoon (managed by chezmoi)

-- Hammerspoon stops a pathwatcher, timer or event tap when Lua garbage-collects
-- it. A local in this file stops protecting an object once the file has
-- loaded, unless a closure that is itself still reachable captures it, so
-- everything that must keep working is owned by this one global table. It is
-- also the place to inspect that state from the Hammerspoon console.
local dotfiles = {}
_G.dotfiles = dotfiles

-- Reload config on file change
dotfiles.configWatcher = hs.pathwatcher
  .new(os.getenv('HOME') .. '/.config/hammerspoon', hs.reload)
  :start()
hs.alert.show('Hammerspoon config loaded')

-------------------------------------------------------------------------------
-- Space switching (vim-style H/L)
--
-- Caps Lock is remapped to Hyper (Cmd+Ctrl+Alt+Shift) by Karabiner-Elements.
-- macOS Mission Control space-switch shortcuts are bound to Hyper+Left and
-- Hyper+Right in System Settings -> Keyboard -> Keyboard Shortcuts ->
-- Mission Control.
--
-- These hotkeys translate Hyper+H / Hyper+L into the native Hyper+Left /
-- Hyper+Right keystrokes, letting macOS handle the actual space transition.
-- That avoids the private hs.spaces API entirely and gives native latency
-- with no Screen Recording / Accessibility quirks.
--
-- Note on latency: routing through Hammerspoon adds ~15-35ms vs. pressing
-- Hyper+Left/Right directly, because the keystroke is intercepted by an
-- event tap, run through a Lua callback, and re-synthesized. If this ever
-- becomes annoying, two faster alternatives:
--   1. Move the H/L -> Left/Right mapping into Karabiner-Elements as a
--      complex modification gated on the Hyper modifier set. Karabiner
--      operates at the HID level (sub-ms) so the result is indistinguishable
--      from pressing Hyper+Left/Right natively, and Hammerspoon stops being
--      involved in space switching at all.
--   2. Use BetterTouchTool for the binding. Still routed through user space,
--      but its native Objective-C path is faster than Hammerspoon's Lua
--      bridge. Only worth it if BTT is already in the toolchain for other
--      reasons -- not worth adopting just for this.
-------------------------------------------------------------------------------

local hyper = { 'cmd', 'ctrl', 'alt', 'shift' }

hs.hotkey.bind(hyper, 'h', function()
  hs.eventtap.keyStroke(hyper, 'left', 0)
end)
hs.hotkey.bind(hyper, 'l', function()
  hs.eventtap.keyStroke(hyper, 'right', 0)
end)

-------------------------------------------------------------------------------
-- ⌘⌥V → Markdown fenced code block (paste-time)
--
-- Pressing ⌘⌥V captures the current clipboard text and the frontmost
-- application/window, then opens a chooser for a language tag (a preset, or
-- a custom one typed into the query). Choosing a tag formats the text as a
-- Markdown fenced code block, writes it to the pasteboard, and emits a
-- synthetic ⌘V to the captured destination. Escape leaves the clipboard
-- untouched.
--
-- The hotkey is consumed — it does not pass through to the frontmost app.
-- Only one request is active at a time; a second ⌘⌥V while the chooser is
-- open is rejected.
-------------------------------------------------------------------------------

-- Common language tags shown in the chooser list.
-- "No language tag" is prepended at runtime so it always appears first.
local fenceLanguages = {
  'bash', 'zsh', 'sh',
  'go', 'lua', 'python',
  'sql', 'json', 'yaml', 'toml',
  'javascript', 'typescript',
  'rust', 'ruby',
}

-- Build the chooser rows expected by hs.chooser:
--   { text = <display string>, lang = <tag to embed> }
local function buildChooserChoices()
  -- "No language tag" option at the top — lang is empty string.
  local choices = {
    { text = 'No language tag', subText = 'plain triple backticks', lang = '' },
  }
  for _, tag in ipairs(fenceLanguages) do
    table.insert(choices, { text = tag, lang = tag })
  end
  return choices
end

-- Wrap `text` in a Markdown fenced code block.
-- If `lang` is empty the opening fence has no tag.
-- Uses enough backticks to avoid conflicting with backtick runs in the text.
local function wrapInFence(text, lang)
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
  local fence = string.rep('`', n)
  return fence .. lang .. '\n' .. text .. '\n' .. fence
end

-------------------------------------------------------------------------------
-- Paste requests
--
-- Each ⌘⌥V starts one request with an increasing id, and only the newest
-- request is live. Starting a request ends the previous one.
--
--  1. Hotkey (⌘⌥V). The frontmost application and focused window are
--     captured as the paste destination. The clipboard is read in a
--     generation-stable snapshot (change count before and after must match).
--     Non-text or empty clipboard contents are rejected.
--  2. Choosing (chooser). The copied text and its change count stay with the
--     request, and every chooser row carries the request's id. A choice is
--     accepted only for the request its row was built for, and only while
--     the pasteboard is still at that change count; anything newer is left
--     untouched. A cancellation (no choice) carries no id. hs.chooser hides
--     its window before reporting any result. hs.chooser's default global
--     callback returns focus to the window that was active just before the
--     chooser opened.
--  3. Focusing (timer). After the chooser dismisses, the destination window
--     needs to regain focus. A bounded poll waits for the exact captured
--     window to become focused. If the captured window closes, focus goes
--     to a different window or app, or a timeout elapses, the request is
--     cancelled.
--  4. Pasting. Once focus is confirmed, the clipboard generation is
--     rechecked. If still stable, the formatted block is written and a
--     synthetic ⌘V is emitted to the validated destination.
--
-- Every asynchronous entry point is guarded: an error is logged and ends the
-- live request rather than leaving it half done. Logs carry request ids,
-- phases and reasons, never pasteboard contents.
-------------------------------------------------------------------------------

local FOCUS_TIMEOUT = 0.5 -- seconds to wait for destination focus
local FOCUS_POLL = 0.02 -- seconds between focus checks

local log = hs.logger.new('pastefence', 'info')

local paste = {
  lastId = 0,
  active = nil,
  chooserFor = nil,
}
dotfiles.pasteFence = paste

local function stopTimer(req)
  if req.timer then
    req.timer:stop()
    req.timer = nil
  end
end

-- Ends `req` once, releasing its timer and copied text. Ending the request
-- that owns the open chooser also dismisses that chooser for good.
local function finish(req, outcome)
  if req.finished then return end
  stopTimer(req)
  req.finished = true
  req.text = nil
  if paste.active == req then paste.active = nil end
  if paste.chooserFor == req.id then
    paste.chooserFor = nil
    if paste.chooser:isVisible() then paste.chooser:hide() end
  end
  log.f('request %d %s: %s', req.id, req.phase, outcome)
end

-- Runs `fn`, logging an error instead of raising it. Returns true on success.
local function try(where, fn, ...)
  local ok, err = xpcall(fn, debug.traceback, ...)
  if not ok then log.ef('%s failed: %s', where, err) end
  return ok
end

-- Runs a request entry point. After an error, `req` (when given) and the live
-- request are ended, so the next ⌘⌥V starts from a clean state.
local function guarded(where, req, fn, ...)
  if try(where, fn, ...) then return end
  if req then try('cleanup', finish, req, 'ended after error') end
  if paste.active then
    try('cleanup', finish, paste.active, 'ended after error')
  end
  paste.active = nil
  paste.chooserFor = nil
end

-- Reject tags containing newlines, carriage returns, or any backtick
-- (CommonMark info strings must not contain backticks or line breaks).
local function isValidTag(tag)
  if tag:find('[\r\n]') then return false end
  if tag:find('`') then return false end
  return true
end

local function updateChoices(query)
  local choices = buildChooserChoices()
  if query and #query > 0 then
    local matchedIndex = nil
    for i, c in ipairs(choices) do
      if c.lang == query then
        matchedIndex = i
        break
      end
    end
    if matchedIndex then
      -- Move the matched preset to the top so Enter picks it.
      local matched = table.remove(choices, matchedIndex)
      table.insert(choices, 1, matched)
    else
      -- No exact match; prepend a custom tag row.
      if isValidTag(query) then
        table.insert(choices, 1, {
          text = query,
          subText = 'custom language tag',
          lang = query,
        })
      end
    end
  end
  -- hs.chooser returns extra row keys with a choice, so each row names the
  -- request the chooser was opened for.
  for _, c in ipairs(choices) do
    c.requestId = paste.chooserFor
  end
  paste.chooser:choices(choices)
end

local function onChoice(choice)
  local req = paste.active
  if
    not req
    or paste.chooserFor ~= req.id
    or paste.chooser:isVisible()
    or (choice and choice.requestId ~= req.id)
  then
    log.f(
      'ignored a chooser %s from request %s (live request %s)',
      choice and 'choice' or 'cancellation',
      choice and choice.requestId or 'unknown',
      req and req.id or 'none'
    )
    return
  end
  paste.chooserFor = nil

  -- Escape, or the chooser losing focus, reports no choice.
  if not choice then return finish(req, 'dismissed; pasteboard untouched') end
  if type(choice.lang) ~= 'string' then
    return finish(req, 'cancelled; choice has no language tag')
  end

  -- Reject custom tags with newlines, carriage returns, or backticks.
  if not isValidTag(choice.lang) then
    return finish(req, 'cancelled; invalid language tag')
  end

  -- Recheck clipboard generation before proceeding.
  if hs.pasteboard.changeCount() ~= req.generation then
    return finish(req, 'cancelled; pasteboard changed since the snapshot')
  end

  -- Capture the chosen language tag for the focus timer.
  local lang = choice.lang

  req.phase = 'focusing'
  req.focusDeadline = hs.timer.absoluteTime()
    + math.floor(FOCUS_TIMEOUT * 1e9)

  local focusTimer = hs.timer.doEvery(FOCUS_POLL, function()
    guarded('focus poll', req, function()
      -- Check if destination app still exists.
      local apps = hs.application.runningApplications()
      local destStillRunning = false
      for _, app in ipairs(apps) do
        if app:pid() == req.destApp:pid() then
          destStillRunning = true
          break
        end
      end
      if not destStillRunning then
        return finish(req, 'cancelled; destination app closed')
      end

      -- Check timeout.
      if hs.timer.absoluteTime() >= req.focusDeadline then
        return finish(req, 'cancelled; focus timeout')
      end

      -- Check if destination window is focused.
      local focused = hs.window.focusedWindow()
      if not focused then return end -- still waiting

      -- Check if the captured window still exists within its app.
      -- app:allWindows() is the native hs.application method.
      local destWindows = req.destApp:allWindows()
      local windowExists = false
      if destWindows then
        for _, w in ipairs(destWindows) do
          if w:id() == req.destWindow:id() then
            windowExists = true
            break
          end
        end
      end
      if not windowExists then
        return finish(req, 'cancelled; captured window closed')
      end

      if focused:id() ~= req.destWindow:id() then
        -- Focus went elsewhere; check if it's our destination's app.
        local focusedApp = focused:application()
        if focusedApp and focusedApp:pid() == req.destApp:pid() then
          return finish(req, 'cancelled; focus went to a different window')
        else
          return finish(req, 'cancelled; focus went to another app')
        end
      end

      -- Focus confirmed!

      -- Check modifiers before synthetic paste.
      local mods = hs.eventtap.checkKeyboardModifiers()
      if mods.cmd or mods.alt or mods.ctrl or mods.shift then
        -- Modifiers held; retry on next poll.
        return
      end

      -- Stop timer now that we are committing to paste.
      stopTimer(req)

      -- Recheck clipboard generation before formatting.
      if hs.pasteboard.changeCount() ~= req.generation then
        return finish(
          req,
          'cancelled; pasteboard changed while awaiting focus'
        )
      end

      -- Format and write.
      if hs.pasteboard.setContents(wrapInFence(req.text, lang)) then
        -- Another process may have written after our format write.
        if hs.pasteboard.changeCount() ~= req.generation + 1 then
          return finish(
            req,
            'cancelled; pasteboard changed after format write'
          )
        end

        -- Re-validate focus immediately before dispatch.
        -- Race: focus can still shift between this check and keyStroke.
        local finalFocused = hs.window.focusedWindow()
        if
          not finalFocused
          or finalFocused:id() ~= req.destWindow:id()
        then
          -- Formatted text is already on the clipboard; leave it there.
          return finish(req, 'cancelled; focus changed during write')
        end

        -- Emit synthetic Cmd+V targeted at the captured destination.
        hs.eventtap.keyStroke({ 'cmd' }, 'v', 0, req.destApp)
        return finish(req, 'formatted and pasted')
      end

      -- Write failed — ownership-aware recovery.
      local outcome
      if hs.pasteboard.changeCount() ~= req.generation + 1 then
        outcome = 'newer pasteboard data left untouched'
      elseif hs.pasteboard.setContents(req.text) then
        outcome = 'copied text restored'
      else
        outcome = 'copied text could not be restored'
      end
      log.ef('request %d: pasteboard write failed; %s', req.id, outcome)
      finish(req, 'failed; pasteboard write')
    end)
  end)
  req.timer = focusTimer
end

local function onPasteFence()
  guarded('paste fence', nil, function()
    -- Gate: one active request at a time.
    if paste.active then
      log.f('request %d still active; ignoring hotkey', paste.active.id)
      return
    end

    -- Capture destination.
    local destApp = hs.application.frontmostApplication()
    local destWindow = hs.window.focusedWindow()
    if not destApp then
      log.f('no frontmost application; ignoring hotkey')
      hs.alert.show('No frontmost application')
      return
    end
    if not destWindow then
      log.f('no focused window; ignoring hotkey')
      hs.alert.show('No focused window')
      return
    end

    -- Stable snapshot of the clipboard.
    local count1 = hs.pasteboard.changeCount()
    local text = hs.pasteboard.getContents()
    local count2 = hs.pasteboard.changeCount()
    if count1 ~= count2 then
      log.f('unstable clipboard snapshot; ignoring hotkey')
      hs.alert.show('Clipboard changed during read')
      return
    end
    if type(text) ~= 'string' then
      log.f('clipboard is not text; ignoring hotkey')
      hs.alert.show('Clipboard is not text')
      return
    end
    if text == '' then
      log.f('clipboard is empty; ignoring hotkey')
      hs.alert.show('Clipboard is empty')
      return
    end

    -- Create request.
    paste.lastId = paste.lastId + 1
    local req = {
      id = paste.lastId,
      phase = 'choosing',
      text = text,
      generation = count1,
      destApp = destApp,
      destWindow = destWindow,
    }
    local previous = paste.active
    paste.active = req
    if previous then finish(previous, 'superseded by request ' .. req.id) end

    paste.chooserFor = req.id
    paste.chooser:query(nil)
    paste.chooser:show()
    log.f('request %d started', req.id)
  end)
end

paste.chooser = hs.chooser.new(
  function(choice) guarded('chooser result', nil, onChoice, choice) end
)
paste.chooser:queryChangedCallback(
  function(query) guarded('chooser query', nil, updateChoices, query) end
)
paste.chooser:choices(buildChooserChoices())
paste.chooser:placeholderText('Language tag (or type a custom one)…')

-- Register the hotkey. The callback consumes the keystroke.
paste.hotkey = hs.hotkey.bind({ 'cmd', 'alt' }, 'v', onPasteFence)
if not paste.hotkey then
  log.ef('failed to bind Cmd+Opt+V hotkey')
  hs.alert.show('Failed to bind Cmd+Opt+V')
end