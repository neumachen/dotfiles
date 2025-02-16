local denkwerstatt_dir = vim.g.denkwerstatt_dir

if as.falsy(denkwerstatt_dir) then return {} end

local function denkwerstatt_path(path) return string.format('%s/%s', denkwerstatt_dir, path) end

return {
  {
    'epwalsh/obsidian.nvim',
    ft = 'markdown',
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    opts = {
      workspaces = {
        {
          name = 'personal',
          path = denkwerstatt_path('personal'),
        },
        {
          name = 'work',
          path = denkwerstatt_path('arbeit'),
        },
      },
    },
  },
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = 'markdown',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {},
  },
}
