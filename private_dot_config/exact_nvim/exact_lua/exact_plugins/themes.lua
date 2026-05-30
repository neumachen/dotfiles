local nordic_overrides = require('plugins.themes.nordic')

return {
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = require('plugins.themes.tokyonight'),
  },
  {
    'catppuccin/nvim',
    lazy = true,
    name = 'catppuccin',
    opts = require('plugins.themes.catpuccin'),
  },
  {
    'AlexvZyl/nordic.nvim',
    lazy = true,
    opts = nordic_overrides.opts,
    config = function(_, opts)
      local nordic = require('nordic')
      nordic.setup(opts or {})
      nordic.load()
      nordic_overrides.apply_overrides()
    end,
  },
  {
    'rmehri01/onenord.nvim',
    lazy = true,
    opts = require('plugins.themes.onenord'),
    config = function(_, opts) require('onenord').setup(opts) end,
  },
}
