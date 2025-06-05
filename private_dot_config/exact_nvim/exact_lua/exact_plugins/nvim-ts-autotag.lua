return {
  'windwp/nvim-ts-autotag',
  ft = {
    'typescriptreact',
    'javascript',
    'javascriptreact',
    'html',
    'vue',
  },
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  config = function() require('nvim-ts-autotag').setup() end,
}
