return {
  'saecki/crates.nvim',
  tag = 'stable',
  event = 'BufRead Cargo.toml',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function() require('crates').setup() end,
}
