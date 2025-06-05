return {
  'mikavilpas/yazi.nvim',
  event = 'VeryLazy',
  opts = {
    log_level = vim.log.levels.INFO,
    -- if you want to open yazi instead of netrw, see below for more info
    open_for_directories = true,
    keymaps = {
      show_help = '<F1>',
    },
    future_features = {
      -- By default, this is `true`, which means yazi.nvim processes events
      -- before yazi has been closed. If this is `false`, events are processed
      -- in a batch when the user closes yazi. If this is `true`, events are
      -- processed immediately.
      process_events_live = true,
    },
  },
  keys = {
    {
      '<leader><F1>',
      mode = { 'n', 'v' },
      '<cmd>Yazi<cr>',
      desc = 'Open yazi at the current file',
    },
    {
      -- Open in the current working directory
      '<leader><F2>',
      mode = { 'n', 'v' },
      '<cmd>Yazi cwd<cr>',
      desc = "Open the file manager in nvim's working directory",
    },
    {
      -- NOTE: this requires a version of yazi that includes
      -- https://github.com/sxyazi/yazi/pull/1305 from 2024-07-18
      '<leader><F3>',
      mode = { 'n' },
      '<cmd>Yazi toggle<cr>',
      desc = 'Resume the last yazi session',
    },
  },
}
