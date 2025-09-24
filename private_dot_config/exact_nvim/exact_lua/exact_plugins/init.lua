return {
  'nvim-lua/plenary.nvim', -- THE LIBRARY
  'nvim-tree/nvim-web-devicons',
  'echasnovski/mini.icons',
  'neovim/nvim-lspconfig',
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = { library = { { path = 'luvit-meta/library', words = { 'vim%.uv' } } } },
  },
}
