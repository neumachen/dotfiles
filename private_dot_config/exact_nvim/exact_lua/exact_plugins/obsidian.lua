local path = require('utils.path')
local notizen_dir = os.getenv('NOTIZEN_DIR')

if
  not path.dir_exists(notizen_dir, {
    notify_on_missing = true,
    notify_level = vim.log.levels.WARN,
    notify_title = 'Obsidian Plugin',
    notify_message = 'NOTIZEN_DIR directory not found, Obsidian plugin disabled',
  })
then
  return {}
end

local obsidian_vault_main_dir = path.join_path(notizen_dir, 'obsidian', 'main')
if
  not path.dir_exists(obsidian_vault_main_dir, {
    notify_on_missing = true,
    notify_level = vim.log.levels.WARN,
    notify_title = 'Obsidian Plugin',
    notify_message = 'Obsidian vault directory not found, plugin disabled',
  })
then
  return {}
end

return {
  'obsidian-nvim/obsidian.nvim',
  version = '*',
  lazy = true,
  cmd = {
    'ObsidianNew',
    'ObsidianOpen',
    'ObsidianQuickSwitch',
    'ObsidianSearch',
    'ObsidianToday',
    'ObsidianYesterday',
  },
  event = {
    'BufReadPre ' .. path.join_path(obsidian_vault_main_dir, '**', '*.md'),
    'BufNewFile ' .. path.join_path(obsidian_vault_main_dir, '**', '*.md'),
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    workspaces = {
      {
        name = 'main',
        path = obsidian_vault_main_dir,
        overrides = {
          notes_subdir = 'notes',
        },
      },
    },

    notes_subdir = 'notes',

    log_level = vim.log.levels.INFO,

    daily_notes = {
      folder = 'notes/dailies',
      date_format = '%Y-%m-%d',
      alias_format = '%B %-d, %Y',
      default_tags = { 'daily-notes' },
      template = nil,
      workdays_only = true,
    },

    completion = {
      nvim_cmp = false,
      blink = true,
      min_chars = 2,
      create_new = true,
    },

    new_notes_location = 'notes_subdir',
    preferred_link_style = 'wiki',

    templates = {
      folder = 'templates',
      date_format = '%Y-%m-%d',
      time_format = '%H:%M',
    },

    picker = {
      name = 'snacks.pick',
      note_mappings = {
        new = '<C-x>',
        insert_link = '<C-l>',
      },
      tag_mappings = {
        tag_note = '<C-x>',
        insert_tag = '<C-l>',
      },
    },

    backlinks = {
      parse_headers = true,
    },

    sort_by = 'modified',
    sort_reversed = true,

    search_max_lines = 1000,
    open_notes_in = 'current',
  },
  keys = {
    {
      '<leader>o',
      '',
      desc = '+obsidian',
    },
    {
      '<leader>fo',
      '<cmd>Obsidian quick_switch<CR>',
      desc = 'Find Obsidian Note',
    },
    {
      '<leader>oN',
      '<cmd>Obsidian new_from_template<CR>',
      desc = 'New Note From Template',
    },
    { '<leader>oT', '<cmd>Obsidian tags<CR>', desc = 'Tags' },
    {
      '<leader>ol',
      '<cmd>Obsidian link_new<CR>',
      desc = 'New Link',
      mode = 'x',
    },
    { '<leader>on', '<cmd>Obsidian new<CR>', desc = 'New Note' },
    { '<leader>op', '<cmd>Obsidian open<CR>', desc = 'Preview' },
    {
      '<leader>or',
      '<cmd>Obsidian rename<CR>',
      desc = 'Rename Note',
    },
    { '<leader>oj', '', desc = '+journal' },
    {
      '<leader>ojt',
      '<cmd>Obsidian today<CR>',
      desc = "Open Today's Daily Note",
    },
    {
      '<leader>ojT',
      '<cmd>Obsidian tomorrow<CR>',
      desc = "Open Tomorrow's Daily Note",
    },
    {
      '<leader>ojy',
      '<cmd>Obsidian yesterday<CR>',
      desc = "Open Yeterday's Daily Note",
    },
    {
      '<leader>so',
      '<cmd>Obsidian search<CR>',
      desc = 'Search in Obsidian Notes',
    },
  },
}
