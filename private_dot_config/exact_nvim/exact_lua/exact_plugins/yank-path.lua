return {
  'neumachen/yank-path.nvim',
  cmd = 'YankPath',
  keys = {
    {
      '<leader>yy',
      '<cmd>YankPath<cr>',
      mode = { 'n', 'x' },
      desc = 'Yank path (picker)',
    },
    {
      '<leader>ya',
      function() require('yank-path').yank_with('absolute') end,
      mode = { 'n', 'x' },
      desc = 'Yank absolute path',
    },
    {
      '<leader>yf',
      function() require('yank-path').yank_with('filename') end,
      mode = { 'n', 'x' },
      desc = 'Yank filename',
    },
    {
      '<leader>yr',
      function() require('yank-path').yank_with('relative') end,
      mode = { 'n', 'x' },
      desc = 'Yank relative path (N up)',
    },
    {
      '<leader>yp',
      function() require('yank-path').yank_with('project') end,
      mode = { 'n', 'x' },
      desc = 'Yank project-relative path',
    },
  },
  opts = {},
}
