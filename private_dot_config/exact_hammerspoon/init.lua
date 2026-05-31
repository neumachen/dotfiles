-- Hammerspoon config
-- ~/.hammerspoon is a symlink -> ~/.config/hammerspoon (managed by chezmoi)

local hs = hs -- luacheck: ignore

-- Reload config on file change
hs.pathwatcher.new(os.getenv('HOME') .. '/.config/hammerspoon', hs.reload):start()
hs.alert.show('Hammerspoon config loaded')

-------------------------------------------------------------------------------
-- Dual-Command key sequences
--
-- Left Cmd → Right Cmd  fires  Cmd+F12       (Tuna activation)
-- Right Cmd → Left Cmd  fires  Cmd+Shift+F12 (Tuna alternate activation)
--
-- A 500ms window is given between the first and second key press.
-- If any other key is pressed during the window, or the timer expires,
-- the sequence is cancelled and the original key events pass through normally.
-------------------------------------------------------------------------------

local SEQUENCE_TIMEOUT = 0.5 -- seconds

local sequenceState = {
  firstKey  = nil,   -- 'left' or 'right'
  timer     = nil,
}

local function resetSequence()
  if sequenceState.timer then
    sequenceState.timer:stop()
    sequenceState.timer = nil
  end
  sequenceState.firstKey = nil
end

local function fireSequence(mods, key)
  resetSequence()
  hs.eventtap.keyStroke(mods, key, 0)
end

local cmdSequenceWatcher = hs.eventtap.new(
  { hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp },
  function(event)
    local keyCode = event:getKeyCode()
    local eventType = event:getType()
    local isKeyDown = eventType == hs.eventtap.event.types.keyDown

    local leftCmdCode  = hs.keycodes.map['leftcmd']
    local rightCmdCode = hs.keycodes.map['rightcmd']

    -- Only act on key-down events for the command keys
    if not isKeyDown then
      -- Let key-up events pass through always
      return false
    end

    if keyCode == leftCmdCode then
      if sequenceState.firstKey == 'right' then
        -- Right → Left sequence complete: Cmd+Shift+F12
        fireSequence({ 'cmd', 'shift' }, 'f12')
        return true -- consume the event
      else
        -- Start a new Left-first sequence
        resetSequence()
        sequenceState.firstKey = 'left'
        sequenceState.timer = hs.timer.doAfter(SEQUENCE_TIMEOUT, function()
          -- Timeout: pass the original Left Cmd through as a normal modifier
          resetSequence()
        end)
        -- Do NOT consume — let Left Cmd act as a normal modifier in case
        -- the user is doing Cmd+C etc. We only consume on sequence completion.
        return false
      end

    elseif keyCode == rightCmdCode then
      if sequenceState.firstKey == 'left' then
        -- Left → Right sequence complete: Cmd+F12
        fireSequence({ 'cmd' }, 'f12')
        return true -- consume the event
      else
        -- Start a new Right-first sequence
        resetSequence()
        sequenceState.firstKey = 'right'
        sequenceState.timer = hs.timer.doAfter(SEQUENCE_TIMEOUT, function()
          resetSequence()
        end)
        return false
      end

    else
      -- Any other key cancels the sequence and passes through normally
      if sequenceState.firstKey ~= nil then
        resetSequence()
      end
      return false
    end
  end
)

cmdSequenceWatcher:start()
