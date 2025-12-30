---@module "lazy"
---@type LazySpec
return {
  'folke/trouble.nvim',
  event = 'VeryLazy',
  cmd = 'Trouble',
  opts = {},
  keys = {
    {
      '<localleader>T',
      '<cmd>Trouble diagnostics toggle<cr>',
      desc = 'Diagnostics (Trouble)',
    },
    {
      '<localleader>db',
      '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
      desc = 'Buffer Diagnostics (Trouble)',
    },
    {
      '<localleader>dL',
      '<cmd>Trouble loclist toggle<cr>',
      desc = 'Location List (Trouble)',
    },
    {
      '<localleader>dq',
      '<cmd>Trouble qflist toggle<cr>',
      desc = 'Quickfix List (Trouble)',
    },
  },
}
