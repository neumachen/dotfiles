local map = vim.keymap.set

return {
  'NeogitOrg/neogit',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
    'sindrets/diffview.nvim',
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
        telescope = true,
        diffview = true,
      },
    })

    local neogit = require('neogit')
    map('n', '<leader>tN', function() neogit.open() end, {
      desc = 'open Neogit',
    })
    map('n', '<localleader>G', function() neogit.open() end, {
      desc = 'open Neogit',
    })
    map('n', '<leader>tns', function() neogit.open() end, {
      desc = 'open Neogit status buffer',
    })
    map('n', '<leader>tnc', function() neogit.open({ 'commit' }) end, {
      desc = 'open commit buffer',
    })
    map('n', '<leader>tnp', function() neogit.open({ 'pull' }) end, {
      desc = 'open pull popup',
    })
    map('n', '<leader>tnP', function() neogit.open({ 'push' }) end, {
      desc = 'open push popup',
    })
  end,
}
