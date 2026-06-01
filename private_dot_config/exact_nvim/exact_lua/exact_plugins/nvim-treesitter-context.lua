---@module "lazy"
---@type LazySpec
return {
  'nvim-treesitter/nvim-treesitter-context',
  event = { 'BufReadPost', 'BufNewFile' },
  opts = {
    max_lines = 4,
    multiline_threshold = 2,
  },
}
