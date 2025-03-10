local wissensspeicher_dir = vim.g.wissensspeicher_dir

if as.falsy(wissensspeicher_dir) then return {} end

local function wissensspeicher_path(path) return string.format('%s/%s', wissensspeicher_dir, path) end

return {
  {
    'obsidian-nvim/obsidian.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      require('obsidian').setup({
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
            path = wissensspeicher_path('personlich'),
          },
          {
            name = 'work',
            path = wissensspeicher_path('arbeit'),
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
      })
    end,
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
