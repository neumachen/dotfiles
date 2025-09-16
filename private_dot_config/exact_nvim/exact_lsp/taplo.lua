local Lsp = require('utils.lsp')

return {
  cmd = { 'taplo', 'lsp', 'stdio' },
  on_attach = Lsp.on_attach,
  filetypes = { 'toml' },
  root_markers = { '.taplo.toml', 'taplo.toml', '.git' },
}
