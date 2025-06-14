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
        notification = {
          on_open = true,
          on_apply = true,
          on_watch = true,
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
