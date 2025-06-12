local Lsp = require('utils.lsp')
-- gem install ruby-lsp
return {
  cmd = { 'ruby-lsp' },
  on_attach = Lsp.on_attach,
  filetypes = { 'ruby', 'rspec', 'Gemfile' },
  root_markers = { 'Gemfile', '.git' },
}
