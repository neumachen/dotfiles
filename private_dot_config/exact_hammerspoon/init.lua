-- Hammerspoon config
-- ~/.hammerspoon is a symlink -> ~/.config/hammerspoon (managed by chezmoi)

-- Reload config on file change
hs.pathwatcher.new(os.getenv('HOME') .. '/.config/hammerspoon', hs.reload):start()
hs.alert.show('Hammerspoon config loaded')

-------------------------------------------------------------------------------
-- Sequence engine
--
-- A lightweight key-sequence detector. Register sequences with:
--   Sequence.register({ 'key1', 'key2', ... }, timeout_seconds, callback)
--
-- Each key in the sequence must be pressed within `timeout` seconds of the
-- previous one. Any other key press or timeout resets the sequence.
-- Keys in a sequence are consumed and not passed through.
-------------------------------------------------------------------------------

local Sequence = {}
Sequence._watchers = {}

function Sequence.register(keys, timeout, callback)
  local state = {
    keys     = keys,
    timeout  = timeout,
    callback = callback,
    step     = 0,
    timer    = nil,
  }

  local function reset()
    if state.timer then
      state.timer:stop()
      state.timer = nil
    end
    state.step = 0
  end

  local keyCodes = {}
  for _, k in ipairs(keys) do
    keyCodes[hs.keycodes.map[k]] = k
  end

  local watcher = hs.eventtap.new(
    { hs.eventtap.event.types.keyDown },
    function(event)
      local code = event:getKeyCode()
      local expectedCode = hs.keycodes.map[state.keys[state.step + 1]]

      if code == expectedCode then
        state.step = state.step + 1

        if state.timer then
          state.timer:stop()
          state.timer = nil
        end

        if state.step == #state.keys then
          -- Sequence complete
          reset()
          callback()
          return true -- consume
        else
          -- Advance, start timeout for next key
          state.timer = hs.timer.doAfter(state.timeout, reset)
          return true -- consume intermediate keys too
        end
      else
        -- Wrong key — reset and pass through
        reset()
        return false
      end
    end
  )

  watcher:start()
  table.insert(Sequence._watchers, watcher)
end

-------------------------------------------------------------------------------
-- Space switching
--
-- Switches to the space immediately left or right of the current one.
-- Requires Screen Recording permission for Hammerspoon.
-------------------------------------------------------------------------------

local function switchSpace(direction)
  local spaces = hs.spaces.allSpaces()
  local screen  = hs.screen.mainScreen()
  local screenID = screen:getUUID()
  local screenSpaces = spaces[screenID]

  if not screenSpaces or #screenSpaces < 2 then return end

  local current = hs.spaces.focusedSpace()
  for i, spaceID in ipairs(screenSpaces) do
    if spaceID == current then
      local target = screenSpaces[i + direction]
      if target then
        hs.spaces.gotoSpace(target)
      end
      return
    end
  end
end

-------------------------------------------------------------------------------
-- Hyper key bindings
--
-- Hyper = Cmd+Ctrl+Alt+Shift
-- Bound here directly so no System Settings shortcut is needed.
-------------------------------------------------------------------------------

local hyper = { 'cmd', 'ctrl', 'alt', 'shift' }

hs.hotkey.bind(hyper, 'h', function() switchSpace(-1) end)
hs.hotkey.bind(hyper, 'l', function() switchSpace(1) end)

-------------------------------------------------------------------------------
-- Home → End sequence (Moergo) → fires Hyper+Space as activation signal
--
-- Home then End within 500ms sends Cmd+Ctrl+Alt+Shift (Hyper).
-- Neither key is passed through — both are consumed by the sequence.
-- This gives the Moergo a dedicated Hyper trigger without firmware changes.
-------------------------------------------------------------------------------

Sequence.register({ 'home', 'end' }, 0.5, function()
  hs.eventtap.keyStroke({ 'cmd', 'ctrl', 'alt', 'shift' }, 'space', 0)
end)
