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

-- ───────────────────────────────────────────────────────────────────────────
-- Why this is more than just "make an eventtap":
--
-- The previous implementation called hs.application.frontmostApplication()
-- inside the eventtap callback. That is a synchronous AppKit call. Most of
-- the time it returns in microseconds, but right after the chooser closes
-- it can stall briefly while macOS restores focus to the previously-active
-- window. If the next ⌘C lands during that stall, the callback exceeds
-- macOS's eventtap budget and the kernel issues
-- kCGEventTapDisabledByTimeout. Hammerspoon does NOT auto-re-enable the
-- tap; isEnabled() returns false and every subsequent ⌘C is dropped until
-- a config reload re-creates the tap. That is the "works once, then
-- silent" symptom.
--
-- Two structural changes fix it:
--
--   1. The frontmost-app check no longer asks AppKit. An
--      hs.application.watcher updates a plain Lua variable on
--      activate/deactivate, and the eventtap callback reads that variable.
--      The hot path is now O(1) and cannot block.
--
--   2. A 1-second watchdog timer calls tap:start() whenever
--      tap:isEnabled() returns false. macOS can still disable the tap
--      under load or after Secure Input briefly engages; the watchdog
--      brings it back automatically.
--
-- The callback is also wrapped in xpcall so a Lua error inside it (e.g. a
-- nil-deref from a future refactor) doesn't silently disable the tap —
-- the trace goes to the Hammerspoon console instead.
--
-- ───────────────────────────────────────────────────────────────────────────
-- Second failure mode (fixed below at the :show() call site):
--
-- Even with the tap kept alive, the SECOND ⌘C in succession would silently
-- do nothing. Diagnosis: a passive probe eventtap installed in front of the
-- production tap made the bug disappear — the probe's synchronous AppKit
-- access (hs.application.frontmostApplication():name() on the eventtap
-- thread) was inadvertently acting as a run-loop barrier that let the
-- chooser's previous-cycle cleanup finish before the next :show() was
-- requested.
--
-- Root cause: hs.chooser's default globalCallback restores focus to the
-- previously-active window on didClose. That restoration is asynchronous.
-- If :show() is called again while the prior cycle's focus restoration is
-- still in flight, hs.chooser silently no-ops — the panel never appears,
-- no callback fires, no log line. The production eventtap is healthy and
-- still firing; it's the chooser that drops the request on the floor.
--
-- Fix at the :show() call site (no AppKit access on the eventtap thread):
--
--   a. Call fenceChooser:hide() first. This is idempotent when the chooser
--      isn't visible and forces a known starting state when it is.
--   b. Call fenceChooser:query(nil) to clear the search box (documented
--      "clear the query string" form).
--   c. Defer the :show() by one run-loop tick via hs.timer.doAfter(0, …).
--      Yielding control back to the run loop lets any pending didClose /
--      focus-restoration work from the previous cycle finish; on the next
--      tick :show() reliably produces a visible chooser.
--
-- The 50 ms delay before this block (line below) is unchanged — its
-- purpose is to let WezTerm finish writing the selection to the
-- pasteboard, not to wait for chooser cleanup.
-- ───────────────────────────────────────────────────────────────────────────

-- Cached name of whichever app is currently frontmost. Updated by the
-- watcher below; read by the eventtap callback.
local frontmostAppName = nil
local activeApp = hs.application.frontmostApplication()
if activeApp then frontmostAppName = activeApp:name() end

-- hs.application.watcher fires on app activate/deactivate/launch/terminate.
-- We only care about "an app just became frontmost" (activated) — that's
-- when frontmostAppName changes. Keep a reference so the watcher object
-- isn't garbage-collected.
local appWatcher = hs.application.watcher.new(function(name, event, _)
  if event == hs.application.watcher.activated then frontmostAppName = name end
end)
appWatcher:start()

-- The eventtap watches for every keyDown event.
-- It only acts when:
--   • the Cmd modifier is held
--   • the key is "c" (keycode 8)
--   • WezTerm is the frontmost application (read from the cached variable)
local wezTermCopyTap = hs.eventtap.new(
  { hs.eventtap.event.types.keyDown },
  function(e)
    -- xpcall guards the whole callback. If anything inside raises, log
    -- the trace and return false so the event still propagates AND the
    -- eventtap stays alive (an unguarded error here disables the tap).
    local ok, err = xpcall(function()
      -- Gate: Cmd+C only.
      if not (e:getFlags().cmd and e:getKeyCode() == 8) then return end

      -- Gate: WezTerm must be frontmost — answered from the cached
      -- variable, not AppKit, so this is a single Lua comparison.
      if frontmostAppName ~= 'WezTerm' then return end

      -- Schedule the chooser to open after a short delay so WezTerm has
      -- time to finish writing the selection to the clipboard. The timer
      -- runs OFF the eventtap thread, so any cost inside it (chooser
      -- presentation, clipboard read) cannot trip the eventtap timeout.
      hs.timer.doAfter(0.05, function()
        local contents = hs.pasteboard.getContents()
        if contents and #contents > 0 then
          -- Force a known starting state. :hide() is idempotent when the
          -- chooser isn't visible. :query(nil) clears the search box;
          -- queryChangedCallback re-sets the choices list synchronously
          -- in response, so we don't need to call :choices() here too.
          fenceChooser:hide()
          fenceChooser:query(nil)
          -- Yield one run-loop tick before showing. Without this, a
          -- rapid second ⌘C lands while hs.chooser's previous-cycle
          -- didClose / focus-restoration work is still in flight, and
          -- :show() silently no-ops. doAfter(0) is the documented way
          -- to defer to the next run-loop iteration.
          hs.timer.doAfter(0, function() fenceChooser:show() end)
        end
      end)
    end, debug.traceback)

    if not ok then print('wezTermCopyTap callback error: ' .. tostring(err)) end

    return false -- never consume the event — WezTerm still copies
  end
)

wezTermCopyTap:start()

-- Watchdog: macOS can disable the tap (kCGEventTapDisabledByTimeout, or
-- briefly during Secure Input). Hammerspoon does not auto-re-enable. Poll
-- once a second; if the tap went silent, restart it. This is the
-- canonical Hammerspoon workaround referenced in their GitHub issues for
-- long-running eventtaps.
hs.timer.doEvery(1, function()
  if not wezTermCopyTap:isEnabled() then wezTermCopyTap:start() end
end)
