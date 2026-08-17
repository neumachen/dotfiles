---@module 'lazy'
---@type LazySpec
return {
  'NMAC427/guess-indent.nvim',
  event = { 'BufReadPost', 'BufNewFile' },
  opts = {
    -- Never clobber an authoritative EditorConfig decision; guess-indent only
    -- fills the gap when EditorConfig is silent about indentation.
    override_editorconfig = false,
    -- Skip special/non-file buffers where indent detection is meaningless.
    filetype_exclude = {
      'netrw',
      'tutor',
    },
    buftype_exclude = {
      'help',
      'nofile',
      'terminal',
      'prompt',
    },
  },
}
