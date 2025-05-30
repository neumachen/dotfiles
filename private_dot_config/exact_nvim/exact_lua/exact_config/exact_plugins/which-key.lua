return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  config = function()
    local wk = require('which-key')
    wk.setup({
      plugins = { spelling = { enabled = true } },
      layout = { align = 'center' },
    })
  end,
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'echasnovski/mini.icons',
  },
}
