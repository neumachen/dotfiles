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
      { '<leader>c', group = 'code (lsp)', desc = 'Code LSP provided operations' },
      { '<leader>f', group = 'file', desc = 'File operations' },
      { '<leader>g', group = 'git', desc = 'Git related operations' },
      { '<leader>t', group = 'Toggle', desc = 'Toggle plugin operations' },
      { '<leader>w', group = 'window', desc = 'Window operations' },
      { '<localleader>g', group = 'neogit', desc = 'Neogit keymaps' },
      { '<localleader>y', group = 'yazi', desc = 'Yazi nvim commands' },
      -- Groups
      { '<leader>cs', group = 'symbols', desc = 'Symbols operations' },
      { '<leader>gh', group = 'git hunk', desc = 'Git hunk operations' },
      { '<leader>gt', group = 'git toggle', desc = 'Git toggle operations' },
      { '<leader>tn', group = 'neogit toggle', desc = 'Neogit operations' },
    })
  end,
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'echasnovski/mini.icons',
  },
}
