return {
  'mistweaverco/kulala.nvim',
  ft = { 'http' },
  opts = {},
  keys = {
    { '<leader>r', '', desc = '+rest' },
    {
      '<leader>rr',
      '<cmd>lua require("kulala").run()<cr>',
      desc = 'Run request',
    },
    {
      '<leader>ra',
      '<cmd>lua require("kulala").run_all()<cr>',
      desc = 'Run all requests',
    },
    {
      '<leader>ri',
      '<cmd>lua require("kulala").inspect()<cr>',
      desc = 'Inspect request',
    },
    {
      '<leader>rc',
      '<cmd>lua require("kulala").copy()<cr>',
      desc = 'Copy as cURL',
    },
    {
      '<leader>rp',
      '<cmd>lua require("kulala").scratchpad()<cr>',
      desc = 'Open scratchpad',
    },
    {
      '<leader>rt',
      '<cmd>lua require("kulala").toggle_view()<cr>',
      desc = 'Toggle view',
    },
    {
      '<leader>rj',
      '<cmd>lua require("kulala").jump_next()<cr>',
      desc = 'Jump to next request',
    },
    {
      '<leader>rk',
      '<cmd>lua require("kulala").jump_prev()<cr>',
      desc = 'Jump to previous request',
    },
  },
}
