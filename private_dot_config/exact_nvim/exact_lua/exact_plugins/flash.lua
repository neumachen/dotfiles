return {
  'folke/flash.nvim',
  event = 'VeryLazy',
  ---@type Flash.Config
  opts = {
    modes = {
      char = {
        keys = { 'f', 'F', 't', 'T', ';' }, -- remove "," from keys },
        search = { enabled = false },
      },
      jump = { nohlsearch = true },
    },
  },
  keys = {
    { '<localleader>s', function() require('flash').jump() end, mode = { 'n', 'x', 'o' } },
    { '<localleader>S', function() require('flash').treesitter() end, mode = { 'o', 'x' } },
    { '<localleader>r', function() require('flash').remote() end, mode = 'o', desc = 'Remote Flash' },
    {
      '<c-s>',
      function() require('flash').toggle() end,
      mode = { 'c' },
      desc = 'Toggle Flash Search',
    },
    {
      '<localleader>R',
      function() require('flash').treesitter_search() end,
      mode = { 'o', 'x' },
      desc = 'Flash Treesitter Search',
    },
  },
}
