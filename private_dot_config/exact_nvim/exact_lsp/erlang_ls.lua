local Lsp = require('utils.lsp')

return {
  cmd = { 'erlang_ls' },
  on_attach = Lsp.on_attach,
  filetypes = { 'erlang' },
  root_markers = { 'rebar.config', 'erlang.mk', '.git' },
}
