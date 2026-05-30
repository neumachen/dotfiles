---@module 'lazy'
---@type LazySpec
return {
  'esmuellert/codediff.nvim',
  cmd = { 'CodeDiff' },
  keys = {
    {
      '<localleader>gd',
      '<cmd>CodeDiff<cr>',
      desc = 'codediff: open (working tree vs HEAD)',
    },
    {
      '<localleader>gh',
      '<cmd>CodeDiff history %<cr>',
      desc = 'codediff: file history',
    },
  },
  ---@type table
  opts = {
    -- Highlights left at defaults: codediff auto-detects dark/light and uses
    -- DiffAdd/DiffDelete from the active colorscheme.
    diff = {
      layout = 'side-by-side',
      disable_inlay_hints = true,
      jump_to_first_change = true,
      cycle_next_hunk = true,
      cycle_next_file = true,
      -- compute_moves = false by default; flip to true if you want VSCode-style
      -- "this block moved" indicators (small extra cost on big diffs).
    },
    explorer = {
      position = 'left',
      width = 40,
      view_mode = 'list',
      indent_markers = true,
    },
    history = {
      position = 'bottom',
      height = 15,
      view_mode = 'list',
    },
  },
}
