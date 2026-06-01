-- Hammerspoon config
-- ~/.hammerspoon is a symlink -> ~/.config/hammerspoon (managed by chezmoi)

-- Reload config on file change
hs.pathwatcher.new(os.getenv('HOME') .. '/.config/hammerspoon', hs.reload):start()
hs.alert.show('Hammerspoon config loaded')

-------------------------------------------------------------------------------
-- Space switching
--
-- Switches to the space immediately left or right of the current one.
-- Triggered via Hyper (Cmd+Ctrl+Alt+Shift) + H/L (vim-style).
-- Requires Screen Recording permission for Hammerspoon.
-- No System Settings keyboard shortcut needed.
-------------------------------------------------------------------------------

local function switchSpace(direction)
  local spaces = hs.spaces.allSpaces()
  local screenID = hs.screen.mainScreen():getUUID()
  local screenSpaces = spaces[screenID]

  if not screenSpaces or #screenSpaces < 2 then return end

  local current = hs.spaces.focusedSpace()
  for i, spaceID in ipairs(screenSpaces) do
    if spaceID == current then
      local target = screenSpaces[i + direction]
      if target then hs.spaces.gotoSpace(target) end
      return
    end
  end
end

local hyper = { 'cmd', 'ctrl', 'alt', 'shift' }

hs.hotkey.bind(hyper, 'h', function() switchSpace(-1) end)
hs.hotkey.bind(hyper, 'l', function() switchSpace(1) end)
