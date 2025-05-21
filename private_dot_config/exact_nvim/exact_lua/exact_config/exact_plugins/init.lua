vim.g.rainbow_delimiters = {
  highlight = {
    'RainbowDelimiterRed',
    'RainbowDelimiterYellow',
    'RainbowDelimiterBlue',
    'RainbowDelimiterOrange',
    'RainbowDelimiterGreen',
    'RainbowDelimiterViolet',
    'RainbowDelimiterCyan',
  },
}

return {
  {
    'nvim-lua/plenary.nvim', -- THE LIBRARY
  },
  {
    'nvim-tree/nvim-web-devicons',
  },
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = { library = { { path = 'luvit-meta/library', words = { 'vim%.uv' } } } },
  },
}