local Lsp = require('utils.lsp')

return {
  cmd = { 'marksman', 'server' },
  on_attach = Lsp.on_attach,
  filetypes = { 'markdown', 'markdown.mdx' },
  root_markers = { '.marksman.toml', '.git' },
}
