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
      { '<leader>a', group = 'sidekick', desc = 'Sidekick plugin operations' },
      { '<leader>b', group = 'buffer', desc = 'Buffer operations' },
      { '<leader>cs', group = 'symbols', desc = 'Sybomls operations' },
      { '<leader>f', group = 'file', desc = 'File operations' },
      { '<leader>g', group = 'git', desc = 'Git related operations' },
      { '<leader>t', group = 'Toggle', desc = 'Toggle plugin operations' },
      { '<leader>w', group = 'window', desc = 'Window operations' },
      { '<localleader>g', group = 'neogit', desc = 'Neogit keymaps' },
      { '<localleader>y', group = 'yazi', desc = 'Yazi nvim commands' },
    })
  end,
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'echasnovski/mini.icons',
  },
}
