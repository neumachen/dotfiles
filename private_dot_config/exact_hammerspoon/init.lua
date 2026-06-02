-- Hammerspoon config
-- ~/.hammerspoon is a symlink -> ~/.config/hammerspoon (managed by chezmoi)

-- Reload config on file change
hs.pathwatcher.new(os.getenv('HOME') .. '/.config/hammerspoon', hs.reload):start()
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
