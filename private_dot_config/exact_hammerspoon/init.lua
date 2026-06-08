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

-------------------------------------------------------------------------------
-- WezTerm ⌘C → Markdown fenced code block
--
-- When WezTerm is frontmost and ⌘C is pressed, the normal copy still happens
-- (we return false so the event propagates). After a short delay to let
-- WezTerm finish writing to the clipboard, we open a chooser so you can pick
-- (or type) a language tag. On selection the clipboard text is wrapped in a
-- Markdown fenced code block and written back, ready to paste elsewhere.
--
-- The eventtap is completely independent of the hyper space-switching above.
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
local function wrapInFence(text, lang)
  return '```' .. lang .. '\n' .. text .. '\n```'
end

-- The chooser is created once and reused to avoid repeated allocation.
local fenceChooser

local function initFenceChooser()
  fenceChooser = hs.chooser.new(function(choice)
    -- choice is nil when the user dismisses with Escape — leave clipboard alone.
    if not choice then return end

    local contents = hs.pasteboard.getContents()
    if contents and #contents > 0 then
      hs.pasteboard.setContents(wrapInFence(contents, choice.lang))
    end
  end)

  -- Allow typing a custom language name not in the preset list.
  -- When the user types something that doesn't match any row, hs.chooser
  -- surfaces a synthetic choice whose `text` equals the query string.
  -- We handle that by treating the typed text as the language tag.
  fenceChooser:queryChangedCallback(function(query)
    local choices = buildChooserChoices()
    -- If the query is non-empty and doesn't exactly match any preset tag,
    -- prepend a "use as custom tag" row so the user can confirm with Enter.
    if query and #query > 0 then
      local matched = false
      for _, c in ipairs(choices) do
        if c.lang == query then matched = true; break end
      end
      if not matched then
        table.insert(choices, 1, {
          text = query,
          subText = 'custom language tag',
          lang = query,
        })
      end
    end
    fenceChooser:choices(choices)
  end)

  fenceChooser:choices(buildChooserChoices())
  fenceChooser:placeholderText('Language tag (or type a custom one)…')
end

-- Initialise the chooser immediately so it is ready on first use.
initFenceChooser()

-- The eventtap watches for every keyDown event.
-- It only acts when:
--   • the Cmd modifier is held
--   • the key is "c" (keycode 8)
--   • WezTerm is the frontmost application
local wezTermCopyTap = hs.eventtap.new(
  { hs.eventtap.event.types.keyDown },
  function(e)
    -- Gate: Cmd+C only.
    if not (e:getFlags().cmd and e:getKeyCode() == 8) then
      return false  -- not our event — propagate unchanged
    end

    -- Gate: WezTerm must be frontmost.
    local app = hs.application.frontmostApplication()
    if not app or app:name() ~= 'WezTerm' then
      return false  -- different app — propagate unchanged
    end

    -- Return false NOW so WezTerm receives ⌘C and copies normally.
    -- We schedule the chooser to open after a short delay (50 ms) to give
    -- WezTerm time to finish writing the selection to the clipboard.
    hs.timer.doAfter(0.05, function()
      local contents = hs.pasteboard.getContents()
      -- Only show the chooser when there is actually something on the clipboard.
      if contents and #contents > 0 then
        -- Reset query so previous searches don't linger between invocations.
        fenceChooser:query('')
        fenceChooser:choices(buildChooserChoices())
        fenceChooser:show()
      end
    end)

    return false  -- do NOT consume the event — WezTerm still copies
  end
)

wezTermCopyTap:start()
