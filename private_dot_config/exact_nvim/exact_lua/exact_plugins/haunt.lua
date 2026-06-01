---@module 'lazy'
---@type LazySpec
return {
  'TheNoeTrevino/haunt.nvim',
  event = 'VeryLazy',
  dependencies = {
    -- Optional picker integrations. Both are already part of this config, so
    -- haunt's "auto" mode will prefer snacks.nvim and fall back to fzf-lua.
    'folke/snacks.nvim',
    'ibhagwan/fzf-lua',
  },
  ---@class HauntConfig
  opts = {
    sign = '󱙝',
    sign_hl = 'DiagnosticInfo',
    virt_text_hl = 'HauntAnnotation', -- links to DiagnosticVirtualTextHint
    annotation_prefix = ' 󰆉 ',
    annotation_suffix = '',
    line_hl = nil,
    virt_text_pos = 'eol',
    data_dir = nil,
    per_branch_bookmarks = true,
    -- "auto" picks snacks first, then telescope, then fzf-lua, then vim.ui.select.
    picker = 'auto',
    picker_keys = {
      delete = { key = 'd', mode = { 'n' } },
      edit_annotation = { key = 'a', mode = { 'n' } },
    },
  },
  init = function()
    local map = vim.keymap.set
    local prefix = '<leader>h'

    local function haunt() return require('haunt.api') end
    local function picker() return require('haunt.picker') end

    -- annotations
    map(
      'n',
      prefix .. 'a',
      function() haunt().annotate() end,
      { desc = 'Haunt: annotate line' }
    )
    map(
      'n',
      prefix .. 't',
      function() haunt().toggle_annotation() end,
      { desc = 'Haunt: toggle annotation' }
    )
    map(
      'n',
      prefix .. 'T',
      function() haunt().toggle_all_lines() end,
      { desc = 'Haunt: toggle all annotations' }
    )
    map(
      'n',
      prefix .. 'd',
      function() haunt().delete() end,
      { desc = 'Haunt: delete bookmark' }
    )
    map(
      'n',
      prefix .. 'C',
      function() haunt().clear_all() end,
      { desc = 'Haunt: clear all bookmarks' }
    )

    -- move
    map(
      'n',
      prefix .. 'p',
      function() haunt().prev() end,
      { desc = 'Haunt: prev bookmark' }
    )
    map(
      'n',
      prefix .. 'n',
      function() haunt().next() end,
      { desc = 'Haunt: next bookmark' }
    )

    -- picker
    map(
      'n',
      prefix .. 'l',
      function() picker().show() end,
      { desc = 'Haunt: show picker' }
    )

    -- quickfix
    map(
      'n',
      prefix .. 'q',
      function() haunt().to_quickfix({ current_buffer = true }) end,
      {
        desc = 'Haunt: send buffer hauntings to quickfix',
      }
    )
    map('n', prefix .. 'Q', function() haunt().to_quickfix() end, {
      desc = 'Haunt: send all hauntings to quickfix',
    })

    -- yank
    map(
      'n',
      prefix .. 'y',
      function() haunt().yank_locations({ current_buffer = true }) end,
      {
        desc = 'Haunt: yank buffer hauntings',
      }
    )
    map('n', prefix .. 'Y', function() haunt().yank_locations() end, {
      desc = 'Haunt: yank all hauntings',
    })
  end,
}
