return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'nvim-mini/mini.icons',
  },
  config = function()
    local wk = require('which-key')

    wk.setup({
      preset = 'modern',
      notify = true,
      plugins = {
        spelling = {
          enabled = true,
        },
      },
      layout = { align = 'center' },
      triggers = {
        { '<leader>', mode = { 'n', 'v' } },
        { '<localleader>', mode = { 'n', 'v' } },
      },
    })

    wk.add({
      -- Leader groups
      { '<leader>b', group = '+buffer', desc = 'Buffer operations' },
      {
        '<leader>c',
        group = '+code (lsp)',
        desc = 'Code LSP provided operations',
      },
      { '<leader>f', group = '+file', desc = 'File operations' },
      { '<leader>g', group = '+git', desc = 'Git operations' },
      { '<leader>m', group = '+marker', desc = 'Marker operations' },
      {
        '<leader>n',
        group = '+notification',
        desc = 'Snacks plugin for notification operations',
      },
      {
        '<leader>s',
        group = '+find/search',
        desc = 'Finding/searching operations',
      },
      { '<leader>t', group = '+toggle', desc = 'Toggle operations' },
      { '<leader>w', group = '+window', desc = 'Window operations' },
      { '<leader><tab>', group = '+tab', desc = 'Tab operations' },
      -- Localleader groups
      {
        '<localleader>t',
        group = '+toggle',
        desc = 'Toggle operations',
      },
      { '<localleader>f', group = '+format', desc = 'Format operations' },
      { '<localleader>g', group = '+git', desc = 'Git operations' },
      {
        '<localleader>s',
        group = '+find/search',
        desc = 'Finding/searching operations',
      },
      { '<localleader>y', group = '+yazi', desc = 'Yazi plugin operations' },
      -- Subgroups - Leader
      { '<leader>gh', group = '+hunk', desc = 'Git hunk operations' },
      { '<leader>gl', group = '+log', desc = 'Git Log operations' },
      { '<leader>gt', group = '+toggle', desc = 'Git toggle operations' },
      { '<leader>tn', group = '+neogit', desc = 'Neogit operations' },
      { '<leader>ts', group = '+scooter', desc = 'Scooter operations' },
      -- Subgroups - Localleader
      {
        '<localleader>gb',
        group = '+buffer',
        desc = 'Buffer specific git operations',
      },
      {
        '<localleader>gh',
        group = '+hunk',
        desc = 'Buffer specific git hunk operations',
      },
      {
        '<localleader>tn',
        group = '+Namu',
        desc = 'Namu related operations',
      },
    })
  end,
}
