local wezterm = require('wezterm')
local utils = require('modules.utils')
local keybinds = require('keybinds')
local act = wezterm.action

-- Tokyo Night Storm palette (folke/tokyonight.nvim) — kept in sync with
-- ../colors/tokyonight_storm.toml so the tab bar matches the active scheme.
local tn = {
  bg = '#24283b',
  ansi_black = '#1d202f',
  ansi_blue = '#7aa2f7',
  bright_black = '#414868',
  bright_white = '#c0caf5',
  cursor_bg = '#c0caf5',
  cursor_fg = '#24283b',
}

-- Shells we treat as "no real process running" so the tab falls back to cwd.
local SHELL_PROCESSES = {
  zsh = true,
  bash = true,
  fish = true,
  sh = true,
  dash = true,
  nu = true,
  ['-zsh'] = true,
  ['-bash'] = true,
}

local function cwd_label(pane)
  local cwd_url = pane.current_working_dir
  if cwd_url == nil then return '' end
  local path = cwd_url.file_path or tostring(cwd_url):gsub('^file://[^/]*', '')
  return utils.convert_useful_path(path)
end

-- Extract the tmux session name (#S) from a pane title produced by tmux's
-- `set-titles-string '❐ #S ● #I'`. Returns nil when the pattern is absent.
local function tmux_session_from_title(pane_title)
  if not pane_title or pane_title == '' then return nil end
  -- Match the session name between the leading glyph and the ' ● ' separator.
  local session = pane_title:match('❐%s*(.-)%s*●')
  if session and #session > 0 then return session end
  -- Fallback: strip any leading decorative glyph and trailing window info.
  session = pane_title:match('^%s*[^%w]*%s*([%w%p]+)')
  if session and #session > 0 then return session end
  return nil
end

-- selene: allow(unused_variable)
---@diagnostic disable-next-line: unused-local
local function create_tab_title(tab, tabs, panes, config, hover, max_width)
  local pane = tab.active_pane
  local process = utils.basename(pane.foreground_process_name or '')
  local title

  if tab.tab_title and #tab.tab_title > 0 then
    -- Manual rename (LEADER+;) always wins.
    title = tab.tab_title
  elseif process == 'tmux' then
    -- Foreground process is tmux itself: show the session name, not "tmux tmux".
    local session = tmux_session_from_title(pane.title)
    title = session and ('tmx-' .. session) or 'tmx'
  elseif process ~= '' and not SHELL_PROCESSES[process] then
    -- A real foreground process (nvim, htop, …) is running: show its name.
    title = process
  else
    -- Plain shell: fall back to the active workspace (session) name.
    local workspace = wezterm.mux.get_active_workspace()
    if workspace and #workspace > 0 then
      title = workspace
    else
      title = cwd_label(pane)
      if title == '' then title = process end
    end
  end

  title = wezterm.truncate_right(title, max_width)

  local copy_mode, n = string.gsub(pane.title, '(.+) mode: .*', '%1', 1)
  if copy_mode == nil or n == 0 then
    copy_mode = ''
  else
    copy_mode = copy_mode .. ': '
  end
  local zoomed = ''
  if pane.is_zoomed then zoomed = '[Z]' end
  return zoomed .. copy_mode .. tab.tab_index + 1 .. ':' .. title
end

---------------------------------------------------------------
--- wezterm on
---------------------------------------------------------------
wezterm.on(
  'format-tab-title',
  function(tab, tabs, panes, config, hover, max_width)
    local title = create_tab_title(tab, tabs, panes, config, hover, max_width)

    -- selene: allow(undefined_variable)
    local solid_left_arrow = utf8.char(0x2590)
    -- selene: allow(undefined_variable)
    local solid_right_arrow = utf8.char(0x258c)
    local edge_background = tn.bg
    local background = tn.ansi_black
    local foreground = tn.ansi_blue

    if tab.is_active then
      background = tn.bright_black
      foreground = tn.bright_white
    elseif hover then
      background = tn.cursor_bg
      foreground = tn.cursor_fg
    end
    local edge_foreground = background

    return {
      { Attribute = { Intensity = 'Bold' } },
      { Background = { Color = edge_background } },
      { Foreground = { Color = edge_foreground } },
      { Text = solid_left_arrow },
      { Background = { Color = background } },
      { Foreground = { Color = foreground } },
      { Text = title },
      { Background = { Color = edge_background } },
      { Foreground = { Color = edge_foreground } },
      { Text = solid_right_arrow },
      { Attribute = { Intensity = 'Normal' } },
    }
  end
)

-- https://github.com/wez/wezterm/issues/1680
-- selene: allow(unused_variable)
---@diagnostic disable-next-line: unused-function, unused-local
local function update_window_background(window, pane)
  -- Placeholder for future per-pane background overrides if needed
  -- Currently using Tokyo Night Storm globally
end

-- selene: allow(unused_variable)
---@diagnostic disable-next-line: unused-function, unused-local
local function update_tmux_style_tab(window, pane)
  local cwd_uri = pane:get_current_working_dir()
  ---@diagnostic disable-next-line: unused-local
  local hostname, cwd = utils.split_from_url(cwd_uri)
  return {
    { Attribute = { Underline = 'Single' } },
    { Attribute = { Italic = true } },
    { Text = hostname },
  }
end

-- selene: allow(unused_variable)
---@diagnostic disable-next-line: unused-local
local function update_ssh_status(window, pane)
  local text = pane:get_domain_name()
  if text == 'local' then text = '' end
  return {
    { Attribute = { Italic = true } },
    { Text = text .. ' ' },
  }
end

-- selene: allow(unused_variable)
---@diagnostic disable-next-line: unused-function, unused-local
local function display_ime_on_right_status(window, pane)
  local compose = window:composition_status()
  if compose then compose = 'COMPOSING: ' .. compose end
  window:set_right_status(compose)
end

-- selene: allow(unused_variable)
---@diagnostic disable-next-line: unused-local
local function display_copy_mode(window, pane)
  local name = window:active_key_table()
  if name then name = 'Mode: ' .. name end
  return { { Attribute = { Italic = false } }, { Text = name or '' } }
end

wezterm.on('update-right-status', function(window, pane)
  -- local tmux = update_tmux_style_tab(window, pane)
  local ssh = update_ssh_status(window, pane)
  local copy_mode = display_copy_mode(window, pane)
  update_window_background(window, pane)
  local workspace = { { Text = window:active_workspace() .. ' ' } }
  local status = utils.merge_lists(utils.merge_lists(workspace, ssh), copy_mode)
  window:set_right_status(wezterm.format(status))
end)

-- selene: allow(unused_variable)
---@diagnostic disable-next-line: unused-local
wezterm.on('toggle-tmux-keybinds', function(window, pane)
  local overrides = window:get_config_overrides() or {}
  if not overrides.window_background_opacity then
    overrides.window_background_opacity = 0.95
    overrides.keys = keybinds.default_keybinds
  else
    overrides.window_background_opacity = nil
    overrides.keys =
      utils.merge_lists(keybinds.default_keybinds, keybinds.tmux_keybinds)
  end
  window:set_config_overrides(overrides)
end)

-- Transparency level used by the LEADER+o toggle below. The opaque side of
-- the toggle is deliberately absent rather than 1.0, so ../wezterm.lua's
-- window_background_opacity stays the single source of truth for it.
local TOGGLE_OPACITY = 0.85

-- Per-window opacity toggle bound to LEADER+o in ../keybinds.lua. Distinct
-- from 'toggle-tmux-keybinds' above, which couples opacity to a key-map swap.
-- The current overrides are read back and mutated in place so unrelated
-- overrides -- `keys` above all -- survive the toggle. Clearing the key (as
-- opposed to writing 1.0) is what restores the configured default. Overrides
-- are per-window and are not persisted, so other and future windows stay
-- opaque until they are toggled themselves.
-- selene: allow(unused_variable)
---@diagnostic disable-next-line: unused-local
wezterm.on('toggle-opacity', function(window, pane)
  local overrides = window:get_config_overrides() or {}
  if overrides.window_background_opacity == nil then
    overrides.window_background_opacity = TOGGLE_OPACITY
  else
    overrides.window_background_opacity = nil
  end
  window:set_config_overrides(overrides)
end)

-- workspace status is now integrated into the main update-right-status handler above

local io = require('io')
local os = require('os')

wezterm.on('trigger-nvim-with-scrollback', function(window, pane)
  local scrollback = pane:get_lines_as_text()
  local name = os.tmpname()
  local f = io.open(name, 'w+')
  if f == nil then return end
  f:write(scrollback)
  f:flush()
  f:close()
  window:perform_action(
    act({
      SpawnCommandInNewTab = {
        args = {
          os.getenv('HOME') .. '/.local/share/zsh/zinit/polaris/bin/nvim',
          name,
        },
      },
    }),
    pane
  )
  wezterm.sleep_ms(1000)
  os.remove(name)
end)

-- https://github.com/wez/wezterm/issues/2979#issuecomment-1447519267
local hacky_user_commands = {
  -- selene: allow(unused_variable)
  ---@diagnostic disable-next-line: unused-local
  ['scroll-up'] = function(window, pane, cmd_context)
    window:perform_action(wezterm.action({ ScrollByPage = -1 }), pane)
    -- wezterm.action({ ScrollByPage = -1 })
  end,
  -- selene: allow(unused_variable)
  ---@diagnostic disable-next-line: unused-local
  ['scroll-down'] = function(window, pane, cmd_context)
    window:perform_action(wezterm.action({ ScrollByPage = 1 }), pane)
  end,
}

wezterm.on('user-var-changed', function(window, pane, name, value)
  if name == 'hacky-user-command' then
    local cmd_context = wezterm.json_parse(value)
    hacky_user_commands[cmd_context.cmd](window, pane, cmd_context)
    return
  end
end)
