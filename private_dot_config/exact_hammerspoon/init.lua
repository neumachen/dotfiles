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
-- Design notes — three failure modes this code defends against
-- ───────────────────────────────────────────────────────────────────────────
--
-- 1. Eventtap disabled by macOS (the "works once, then silent" symptom).
--
--    The original implementation called hs.application.frontmostApplication()
--    inside the eventtap callback. That is a synchronous AppKit call. Most
--    of the time it returns in microseconds, but right after the chooser
--    closes it can stall briefly while macOS restores focus. If the next
--    ⌘C lands during that stall, the callback exceeds macOS's eventtap
--    budget and the kernel issues kCGEventTapDisabledByTimeout.
--    Hammerspoon does NOT auto-re-enable the tap; every subsequent ⌘C is
--    silently dropped.
--
--    Defenses:
--      • The eventtap callback does NO AppKit work. It only inspects the
--        event's modifier flags and keycode — pure CGEvent reads, no
--        cross-thread calls.
--      • The chooser open is scheduled via hs.timer.doAfter(0.05, …) which
--        runs on the main thread, outside the eventtap timing budget.
--      • A 1-second watchdog restarts the tap if isEnabled() ever returns
--        false (Secure Input toggles, kernel timeouts).
--      • The whole callback is wrapped in xpcall so a Lua error logs a
--        trace instead of silently killing the tap.
--
-- 2. Second ⌘C in succession silently no-ops.
--
--    hs.chooser's default globalCallback restores focus to the previously-
--    active window on didClose. That restoration is asynchronous. If
--    :show() is called again while the prior cycle's focus-restoration is
--    still in flight, hs.chooser silently no-ops — the panel never
--    appears, no callback fires, no log line.
--
--    Defenses (at the :show() call site):
--      a. fenceChooser:hide() — idempotent when not visible; forces a
--         known starting state when it is.
--      b. fenceChooser:query(nil) — clears the search box (documented
--         "clear the query string" form). queryChangedCallback re-runs
--         synchronously and resets the choices list.
--      c. hs.timer.doAfter(0, …) wrapping :show() — yields one run-loop
--         tick so any pending didClose / focus-restoration work from the
--         previous cycle finishes before the next :show().
--
-- 3. Chooser fires in the WRONG app (Brave, Mail, anywhere not WezTerm).
--
--    The previous design cached frontmostAppName via hs.application.watcher
--    and read it from the eventtap. The watcher is asynchronous and
--    unreliable as a single source of truth: its activated events can be
--    missed, can land out of order with hs.chooser's focus-restoration
--    events, or can fail to fire at all when Hammerspoon's own chooser
--    panel briefly owns focus. Once stale, the cache reads "WezTerm"
--    forever and every ⌘C in any app opens the chooser.
--
--    Defense: don't cache. The authoritative
--    hs.application.frontmostApplication():name() check is moved INTO
--    the hs.timer.doAfter(0.05, …) callback. That callback runs on the
--    main thread — not on the eventtap thread — so the AppKit call is
--    free of the timeout concern from failure mode #1. The check is
--    re-evaluated on every ⌘C, so there is no stale state to go wrong.
--    The cached variable, bootstrap query, and hs.application.watcher
--    were removed because they were the source of the bug.
--
-- The 50 ms delay before the chooser opens is unchanged — its purpose is
-- to let WezTerm finish writing the selection to the pasteboard, not to
-- wait for chooser cleanup.
-- ───────────────────────────────────────────────────────────────────────────

-- The eventtap watches for every keyDown event. It does the absolute
-- minimum work synchronously: check modifiers and keycode. The frontmost-
-- app check and chooser presentation happen on the main thread via the
-- 50 ms timer, so the eventtap callback never touches AppKit.
local wezTermCopyTap = hs.eventtap.new(
  { hs.eventtap.event.types.keyDown },
  function(e)
    -- xpcall guards the whole callback. If anything inside raises, log
    -- the trace and return false so the event still propagates AND the
    -- eventtap stays alive (an unguarded error here disables the tap).
    local ok, err = xpcall(function()
      -- Gate: Cmd+C only. Pure CGEvent reads — no AppKit, no blocking.
      if not (e:getFlags().cmd and e:getKeyCode() == 8) then return end

      -- Schedule the rest of the work on the main thread. Both the
      -- frontmost-app check and the chooser presentation run here,
      -- outside the eventtap timing budget. The 50 ms delay also lets
      -- WezTerm finish writing the selection to the pasteboard.
      hs.timer.doAfter(0.05, function()
        -- Authoritative frontmost-app check, evaluated fresh on every
        -- ⌘C. Replaces the previous cached variable, which went stale
        -- when hs.application.watcher missed activation events around
        -- chooser focus restoration.
        local front = hs.application.frontmostApplication()
        if not front or front:name() ~= 'WezTerm' then return end

        local contents = hs.pasteboard.getContents()
        if not (contents and #contents > 0) then return end

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
