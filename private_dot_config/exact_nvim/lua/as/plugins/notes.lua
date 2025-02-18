local denkwerkstatt_dir = vim.g.denkwerkstatt_dir

if as.falsy(denkwerkstatt_dir) then return {} end

local function denkwerkstatt_path(path) return string.format('%s/%s', denkwerkstatt_dir, path) end

return {
  {
    'epwalsh/obsidian.nvim',
    ft = 'markdown',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
    },
    opts = {
      log_level = vim.log.levels.INFO,
      completion = {
        -- Set to false to disable completion.
        nvim_cmp = true,
        -- Trigger completion at 2 chars.
        min_chars = 2,
      },
      workspaces = {
        {
          name = 'personal',
          path = denkwerkstatt_path('personlich'),
        },
        {
          name = 'work',
          path = denkwerkstatt_path('arbeit'),
        },
      },
      picker = {
        -- Set your preferred picker. Can be one of 'telescope.nvim', 'fzf-lua', or 'mini.pick'.
        name = 'telescope.nvim',
        -- Optional, configure key mappings for the picker. These are the defaults.
        -- Not all pickers support all mappings.
        note_mappings = {
          -- Create a new note from your query.
          new = '<C-x>',
          -- Insert a link to the selected note.
          insert_link = '<C-l>',
        },
        tag_mappings = {
          -- Add tag(s) to current note.
          tag_note = '<C-x>',
          -- Insert a tag at the current location.
          insert_tag = '<C-l>',
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
