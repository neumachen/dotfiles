return {
  'nvim-lua/plenary.nvim', -- THE LIBRARY
  'nvim-tree/nvim-web-devicons',
  'echasnovski/mini.icons',
  'neovim/nvim-lspconfig',
  {
    'folke/lazydev.nvim',
    ft = 'lua', -- only load on lua files
    dependencies = {
      {
        'DrKJeff16/wezterm-types',
        lazy = true,
        version = false, -- Get the latest version
      },
    },
    opts = {
      library = {
        'lazy.nvim',
        -- It can also be a table with trigger words / mods
        -- Only load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
        { path = 'wezterm-types', mods = { 'wezterm' } },
      },
      -- Always enable unless `vim.g.lazydev_enabled = false`
      -- This is the default
      ---@diagnostic disable-next-line: unused-local
      enabled = function(root_dir)
        return vim.g.lazydev_enabled == nil and true or vim.g.lazydev_enabled
      end,
    },
  },
}
