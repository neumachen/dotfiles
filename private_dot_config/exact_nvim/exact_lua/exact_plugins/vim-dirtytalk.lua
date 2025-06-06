return {
  'psliwka/vim-dirtytalk',
  lazy = false,
  build = ':DirtytalkUpdate',
  config = function() vim.opt.spelllang:append('programming') end,
}
