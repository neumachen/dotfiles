return {
  'mistweaverco/kulala.nvim',
  ft = { 'http' },
  opts = {},
  keys = {
    { '<leader>r', '', desc = '+rest', ft = 'http' },
    { '<leader>rr', '<cmd>lua require("kulala").run()<cr>', desc = 'Run request', ft = 'http' },
    { '<leader>ra', '<cmd>lua require("kulala").run_all()<cr>', desc = 'Run all requests', ft = 'http' },
    { '<leader>ri', '<cmd>lua require("kulala").inspect()<cr>', desc = 'Inspect request', ft = 'http' },
    { '<leader>rc', '<cmd>lua require("kulala").copy()<cr>', desc = 'Copy as cURL', ft = 'http' },
    { '<leader>rp', '<cmd>lua require("kulala").scratchpad()<cr>', desc = 'Open scratchpad', ft = 'http' },
    { '<leader>rt', '<cmd>lua require("kulala").toggle_view()<cr>', desc = 'Toggle view', ft = 'http' },
    { '<leader>rj', '<cmd>lua require("kulala").jump_next()<cr>', desc = 'Jump to next request', ft = 'http' },
    { '<leader>rk', '<cmd>lua require("kulala").jump_prev()<cr>', desc = 'Jump to previous request', ft = 'http' },
  },
}
