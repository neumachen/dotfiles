return {
  'NeogitOrg/neogit',
  cmd = 'Neogit',
  dependencies = {
    'folke/snacks.nvim',
    'nvim-lua/plenary.nvim',
    'sindrets/diffview.nvim',
  },
  keys = {
    {
      '<leader>tN',
      function() require('neogit').open() end,
      desc = 'open Neogit',
    },
    {
      '<localleader>G',
      function() require('neogit').open() end,
      desc = 'open Neogit',
    },
    {
      '<leader>tnc',
      function() require('neogit').open({ 'commit' }) end,
      desc = 'open commit buffer',
    },
    {
      '<leader>tnp',
      function() require('neogit').open({ 'pull' }) end,
      desc = 'open pull popup',
    },
    {
      '<leader>tnP',
      function() require('neogit').open({ 'push' }) end,
      desc = 'open push popup',
    },
  },
  config = function()
    require('neogit').setup({
      disable_signs = true,
      disable_hint = true,
      disable_commit_confirmation = true,
      disable_builtin_notifications = true,
      disable_insert_on_commit = false,
      disable_line_numbers = false,
      disable_relative_line_numbers = false,
      process_spinner = false,
      floating = {
        relative = 'editor',
        width = 0.8,
        height = 0.7,
        style = 'minimal',
        border = 'rounded',
      },
      signs = {
        section = { '', '󰘕' }, -- "󰁙", "󰁊"
        item = { '', '▾' },
        hunk = { '󰐕', '󰍴' },
      },
      integrations = {
        diffview = true,
        snacks = true,
      },
    })
  end,
}
