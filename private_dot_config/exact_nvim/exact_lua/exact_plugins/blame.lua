return {
  'FabijanZulj/blame.nvim',
  keys = {
    { '<localleader>gB', '<cmd>BlameToggle<cr>', desc = 'Toggle git blame' },
  },
  opts = {
    blame_options = { '-w' },
  },
}
