local keybinds = require('keybinds')
local utils = require('modules.utils')
local wezterm = require('wezterm')
local gpus = wezterm.gui.enumerate_gpus()
-- local scheme = wezterm.get_builtin_color_schemes()['tokyonight_storm']
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
    table.insert(ssh_domains, {
      name = host,
      remote_address = config.hostname .. ':' .. config.port,
      username = config.user,
      multiplexing = 'None',
      assume_shell = 'Posix',
    })
  end
  return { ssh_domains = ssh_domains }
end

--- load local_config
-- Write settings you don't want to make public, such as ssh_domains
package.path = os.getenv('HOME') .. '/.local/share/wezterm/?.lua;' .. package.path
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
      font = wezterm.font('CartographCF Nerd Font', { weight = 'Bold', italic = true }),
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
  -- enable_wayland = enable_wayland(),
  -- https://github.com/wez/wezterm/issues/1772
  enable_wayland = false,
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
  -- colors = {
  --   tab_bar = {
  --     background = scheme.background,
  --     -- new_tab = { bg_color = '#2e3440', fg_color = scheme.ansi[8], intensity = 'Bold' },
  --     -- new_tab_hover = {
  --     --   bg_color = scheme.ansi[1],
  --     --   fg_color = scheme.brights[8],
  --     --   intensity = 'Bold',
  --     -- },
  --     -- format-tab-title
  --     -- active_tab = { bg_color = '#121212', fg_color = '#FCE8C3' },
  --     -- inactive_tab = { bg_color = scheme.background, fg_color = '#FCE8C3' },
  --     -- inactive_tab_hover = { bg_color = scheme.ansi[1], fg_color = '#FCE8C3' },
  --   },
  -- },
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
  leader = { key = 'Escape', mods = 'SHIFT', timeout = 1500 },
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
return utils.merge_tables(merged_config, create_ssh_domain_from_ssh_config(merged_config.ssh_domains))
