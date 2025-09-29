return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  config = function()
    local wk = require('which-key')
    wk.setup({
      plugins = { spelling = { enabled = true } },
      layout = { align = 'center' },
    })
    wk.add({
      { '<localleader>y', group = 'yazi', desc = 'Yazi nvim commands' },
      { '<localleader>g', group = 'neogit', desc = 'Neogit keymaps' },
    })
  end,
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'echasnovski/mini.icons',
  },
}
