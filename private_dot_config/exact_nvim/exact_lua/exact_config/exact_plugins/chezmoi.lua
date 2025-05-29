return {
  'xvzc/chezmoi.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require('chezmoi').setup({
      {
        edit = {
          watch = true,
          force = false,
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
    map('n', '<localleader>fcd', telescope.extensions.chezmoi.find_files, {
      desc = 'edit dotfiles',
    })
  end,
}
