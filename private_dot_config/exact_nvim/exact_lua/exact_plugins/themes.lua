return {
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = require('plugins.themes.tokyonight'),
  },
  {
    'catppuccin/nvim',
    lazy = false,
    priority = 1000,
    name = 'catppuccin',
    opts = require('plugins.themes.catpuccin'),
  },
}
