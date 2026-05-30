return {
  'NeogitOrg/neogit',
  cmd = 'Neogit',
  dependencies = {
    'folke/snacks.nvim',
    'nvim-lua/plenary.nvim',
    'esmuellert/codediff.nvim',
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
      -- Graph rendering style for the log popup. 'kitty' uses the same
      -- glyph technique as gitgraph.nvim (works in any terminal with a Nerd
      -- Font, despite the name). Fall back to 'unicode' if glyphs render
      -- incorrectly in your terminal, or 'ascii' for the plain git CLI look.
      graph_style = 'kitty',
      -- Explicit diff backend. nil = auto-detect (codediff first then diffview);
      -- pinning avoids any ambiguity if a second diff plugin enters the deps tree.
      diff_viewer = 'codediff',
      integrations = {
        codediff = true,
        snacks = true,
      },
    })
  end,
}
