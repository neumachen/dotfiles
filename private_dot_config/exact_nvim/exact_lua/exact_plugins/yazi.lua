return {
  'mikavilpas/yazi.nvim',
  version = '*', -- use the latest stable version
  event = 'VeryLazy',
  dependencies = {
    { 'nvim-lua/plenary.nvim', lazy = true },
  },
  opts = {
    log_level = vim.log.levels.INFO,
    -- if you want to open yazi instead of netrw, see below for more info
    open_for_directories = true,
    integrations = {
      grep_in_directory = 'fzf-lua',
      grep_in_selected_files = 'fzf-lua',
    },
    -- mirror yazi.nvim's upstream defaults verbatim, so the full
    -- in-yazi keymap surface is discoverable here without reading
    -- the plugin source. values match
    -- https://github.com/mikavilpas/yazi.nvim/blob/main/lua/yazi/config.lua
    -- update this block if upstream changes a binding.
    keymaps = {
      show_help = '<f1>',
      open_file_in_vertical_split = '<c-v>',
      open_file_in_horizontal_split = '<c-x>',
      open_file_in_tab = '<c-t>',
      grep_in_directory = '<c-s>',
      replace_in_directory = '<c-g>',
      cycle_open_buffers = '<tab>',
      copy_relative_path_to_selected_files = '<c-y>',
      send_to_quickfix_list = '<c-q>',
      change_working_directory = '<c-\\>',
      open_and_pick_window = '<c-o>',
    },
  },
  keys = {
    {
      '<localleader>yf',
      mode = { 'n', 'v' },
      '<cmd>Yazi<cr>',
      desc = 'Open yazi at the current file',
    },
    {
      -- Open in the current working directory
      '<localleader>yd',
      mode = { 'n', 'v' },
      '<cmd>Yazi cwd<cr>',
      desc = "Open the file manager in nvim's working directory",
    },
    {
      -- NOTE: this requires a version of yazi that includes
      -- https://github.com/sxyazi/yazi/pull/1305 from 2024-07-18
      '<localleader>yr',
      mode = { 'n' },
      '<cmd>Yazi toggle<cr>',
      desc = 'Resume the last yazi session',
    },
  },
}
