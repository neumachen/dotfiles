return {
  'xvzc/chezmoi.nvim',
  event = 'VeryLazy',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require('chezmoi').setup({
      {
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
        telescope = {
          select = { '<CR>' },
        },
      },
    })

    local telescope = require('telescope')
    vim.keymap.set('n', '<leader>fc', telescope.extensions.chezmoi.find_files, {
      desc = 'Find Chezmoi Managed Config Files',
    })
  end,
}
