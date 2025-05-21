return {
  {
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
        -- Whether to use `ya emit reveal` to reveal files in the file manager.
        -- Requires yazi 0.4.0 or later (from 2024-12-08).
        ya_emit_reveal = true,

        -- Use `ya emit open` as a more robust implementation for opening files
        -- in yazi. This can prevent conflicts with custom keymappings for the enter
        -- key. Requires yazi 0.4.0 or later (from 2024-12-08).
        ya_emit_open = true,
      },
    },
    keys = {
      -- 👇 in this section, choose your own keymappings!
      {
        '<leader>-',
        mode = { 'n', 'v' },
        '<cmd>Yazi<cr>',
        desc = 'Open yazi at the current file',
      },
      {
        -- Open in the current working directory
        '<leader>cw',
        '<cmd>Yazi cwd<cr>',
        desc = "Open the file manager in nvim's working directory",
      },
      {
        -- NOTE: this requires a version of yazi that includes
        -- https://github.com/sxyazi/yazi/pull/1305 from 2024-07-18
        '<c-up>',
        '<cmd>Yazi toggle<cr>',
        desc = 'Resume the last yazi session',
      },
    },
  },
}
