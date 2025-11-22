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
      -- Leader groups
      { '<leader>a', group = 'sidekick', desc = 'Sidekick plugin operations' },
      { '<leader>b', group = 'buffer', desc = 'Buffer operations' },
      { '<leader>c', group = 'code (lsp)', desc = 'Code LSP provided operations' },
      { '<leader>f', group = 'file', desc = 'File operations' },
      { '<leader>g', group = 'git', desc = 'Git operations' },
      { '<leader>m', group = 'marker', desc = 'Marker operations' },
      { '<leader>n', group = 'notification', desc = 'Snacks plugin for notification operations' },
      { '<leader>s', group = 'find/search', desc = 'Finding/searching operations' },
      { '<leader>t', group = 'toggle', desc = 'Toggle plugin operations' },
      { '<leader>w', group = 'window', desc = 'Window operations' },
      { '<leader><tab>', group = 'tab', desc = 'Tab operations' },
      -- Localleader groups
      { '<localleader>g', group = 'git', desc = 'Git operations' },
      { '<localleader>y', group = 'yazi', desc = 'Yazi plugin operations' },
      -- Subgroups
      -- Leader
      { '<leader>cs', group = 'symbols', desc = 'Symbols operations' },
      { '<leader>gh', group = 'git hunk', desc = 'Git hunk operations' },
      { '<leader>gt', group = 'git toggle', desc = 'Git toggle operations' },
      { '<leader>tn', group = 'neogit', desc = 'Neogit operations' },
    })
  end,
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'echasnovski/mini.icons',
  },
}
