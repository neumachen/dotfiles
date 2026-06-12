local keybinds = require('keybinds')
local utils = require('modules.utils')
local wezterm = require('wezterm')
local gpus = wezterm.gui.enumerate_gpus()
require('modules.commands')

-- /etc/ssh/sshd_config
-- AcceptEnv TERM_PROGRAM_VERSION COLORTERM TERM TERM_PROGRAM WEZTERM_REMOTE_PANE
-- sudo systemctl reload sshd

---------------------------------------------------------------
--- functions
---------------------------------------------------------------
-- selene: allow(unused_variable)
---@diagnostic disable-next-line: unused-function, unused-local
local function enable_wayland()
  local wayland = os.getenv('XDG_SESSION_TYPE')
  if wayland == 'wayland' then return true end
  return false
end

---------------------------------------------------------------
--- Merge the Config
---------------------------------------------------------------
local function create_ssh_domain_from_ssh_config(ssh_domains)
  if ssh_domains == nil then ssh_domains = {} end
  for host, config in pairs(wezterm.enumerate_ssh_hosts()) do
    local hostname = config.hostname or host
    local port = config.port or '22'
    table.insert(ssh_domains, {
      name = host,
      remote_address = hostname .. ':' .. port,
      username = config.user,
      multiplexing = 'None',
      assume_shell = 'Posix',
    })
  end
  return { ssh_domains = ssh_domains }
end

--- load local_config
-- Write settings you don't want to make public, such as ssh_domains
package.path = os.getenv('HOME')
  .. '/.local/share/wezterm/?.lua;'
  .. package.path
local function load_local_config(module)
  local m = package.searchpath(module, package.path)
  if m == nil then return {} end
  return dofile(m)
  -- local ok, _ = pcall(require, "local")
  -- if not ok then
  -- 	return {}
  -- end
  -- return require("local")
end

local local_config = load_local_config('local')

-- local local_config = {
-- 	ssh_domains = {
-- 		{
-- 			-- This name identifies the domain
-- 			name = "my.server",
-- 			-- The address to connect to
-- 			remote_address = "192.168.8.31",
-- 			-- The username to use on the remote host
-- 			username = "katayama",
-- 		},
-- 	},
-- }
-- return local_config

---------------------------------------------------------------
--- Config
---------------------------------------------------------------
local config = {
  font = wezterm.font('CartographCF Nerd Font'),
  term = 'wezterm',
  font_size = 15.0,
  cell_width = 1.0,
  line_height = 1.0,
  font_rules = {
    {
      italic = true,
      font = wezterm.font('CartographCF Nerd Font', { italic = true }),
    },
    {
      italic = true,
      intensity = 'Bold',
      font = wezterm.font(
        'CartographCF Nerd Font',
        { weight = 'Bold', italic = true }
      ),
    },
  },
  check_for_updates = true,
  use_ime = true,
  ime_preedit_rendering = 'System',
  use_dead_keys = false,
  warn_about_missing_glyphs = false,
  enable_kitty_graphics = true,
  animation_fps = 1,
  cursor_blink_ease_in = 'Constant',
  cursor_blink_ease_out = 'Constant',
  cursor_blink_rate = 0,
  default_workspace = 'main',
  -- enable_wayland = enable_wayland(),
  -- https://github.com/wez/wezterm/issues/1772
  enable_wayland = false,
  -- Advertise the dedicated wezterm terminfo entry instead of the default
  -- xterm-256color. Requires the terminfo to be installed first:
  --   tempfile=$(mktemp) \
  --     && curl -o $tempfile https://raw.githubusercontent.com/wezterm/wezterm/main/termwiz/data/wezterm.terminfo \
  --     && tic -x -o ~/.terminfo $tempfile \
  --     && rm $tempfile
  term = 'wezterm',
  color_scheme = 'tokyonight_storm',
  color_scheme_dirs = { os.getenv('HOME') .. '/.config/wezterm/colors/' },
  hide_tab_bar_if_only_one_tab = false,
  adjust_window_size_when_changing_font_size = false,
  selection_word_boundary = ' \t\n{}[]()"\'`,;:│=&!%',
  window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
  },
  window_decorations = 'INTEGRATED_BUTTONS|RESIZE',
  integrated_title_buttons = { 'Close' },
  use_fancy_tab_bar = false,
  show_new_tab_button_in_tab_bar = false,
  exit_behavior = 'CloseOnCleanExit',
  tab_bar_at_bottom = false,
  window_close_confirmation = 'AlwaysPrompt',
  quit_when_all_windows_are_closed = true,
  window_background_opacity = 1.0,
  disable_default_key_bindings = true,
  visual_bell = {
    fade_in_function = 'EaseIn',
    fade_in_duration_ms = 150,
    fade_out_function = 'EaseOut',
    fade_out_duration_ms = 150,
  },
  -- separate <Tab> <C-i>
  enable_csi_u_key_encoding = true,
  -- treat both Alt keys as real Alt modifiers rather than as compose
  -- keys for typing accented characters. wezterm's defaults are
  -- left=true (compose), right=false (real Alt), which breaks
  -- <A-...> bindings in nvim when the user reaches for left Alt by
  -- reflex (e.g., yazi.nvim's <A-v>/<A-x> pick-then-split keymaps,
  -- and most lazyvim-style configs that use Alt in their bindings).
  -- accented-character entry remains available by switching keyboard
  -- layouts when needed.
  send_composed_key_when_left_alt_is_pressed = false,
  send_composed_key_when_right_alt_is_pressed = false,
  leader = { key = 'b', mods = 'CTRL', timeout = 1000 },
  keys = keybinds.create_keybinds(),
  key_tables = keybinds.key_tables,
  mouse_bindings = keybinds.mouse_bindings,
  -- https://github.com/wez/wezterm/issues/2756
  webgpu_preferred_adapter = gpus[1],
  front_end = 'WebGpu',
}

config.hyperlink_rules = wezterm.default_hyperlink_rules()
table.insert(config.hyperlink_rules, {
  regex = [[["]?([\w\d]{1}[-\w\d]+)(/){1}([-\w\d\.]+)["]?]],
  format = 'https://github.com/$1/$3',
})

local merged_config = utils.merge_tables(config, local_config)
return utils.merge_tables(
  merged_config,
  create_ssh_domain_from_ssh_config(merged_config.ssh_domains)
)
