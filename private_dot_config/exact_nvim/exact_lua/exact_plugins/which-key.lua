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
      { '<leader>f', group = 'file', desc = 'File operations' },
      { '<leader>g', group = 'git', desc = 'Git related operations' },
      { '<leader>b', group = 'buffer', desc = 'Buffer operations' },
      { '<leader>w', group = 'window', desc = 'Window operations' },
      { '<localleader>y', group = 'yazi', desc = 'Yazi nvim commands' },
      { '<localleader>g', group = 'neogit', desc = 'Neogit keymaps' },
    })
  end,
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'echasnovski/mini.icons',
  },
}
