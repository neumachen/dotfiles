local home = os.getenv('HOME')
local plugin_dir = '.local/share/wezterm/plugins/smart-splits.nvim'
local plugin_path = home .. '/' .. plugin_dir

local wezterm = require('wezterm')
local smart_splits = wezterm.plugin.require(plugin_path)
local config = wezterm.config_builder()

smart_splits.apply_to_config(config, {
  direction_keys = {
    move = { 'h', 'j', 'k', 'l' },
    resize = { 'LeftArrow', 'DownArrow', 'UpArrow', 'RightArrow' },
  },
  -- modifier keys to combine with direction_keys
  modifiers = {
    move = 'CTRL', -- modifier to use for pane movement, e.g. CTRL+h to move left
    resize = 'META', -- modifier to use for pane resize, e.g. META+h to resize to the left
  },
  -- log level to use: info, warn, error
  log_level = 'info',
})
