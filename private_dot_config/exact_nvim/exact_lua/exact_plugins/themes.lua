return {
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = require('plugins.themes.tokyonight'),
  },
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    lazy = false,
    opts = require('plugins.themes.catpuccin'),
  },
}
