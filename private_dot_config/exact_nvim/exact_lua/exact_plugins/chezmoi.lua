return {
  'xvzc/chezmoi.nvim',
  event = 'VeryLazy',
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('chezmoi').setup({
      edit = {
        watch = true,
        force = true,
      },
      events = {
        on_open = {
          notification = {
            enable = true,
            msg = 'Opened a chezmoi-managed file',
            opts = {},
          },
        },
        on_watch = {
          notification = {
            enable = true,
            msg = 'This file will be automatically applied',
            opts = {},
          },
        },
        on_apply = {
          notification = {
            enable = true,
            msg = 'Successfully applied',
            opts = {},
          },
        },
      },
    })

    vim.keymap.set(
      'n',
      '<leader>fc',
      function()
        require('chezmoi.pick').snacks({
          '--path-style',
          'absolute',
          '--include',
          'files',
          '--exclude',
          'externals',
        })
      end,
      { desc = 'Search all chezmoi managed files' }
    )
  end,
}
