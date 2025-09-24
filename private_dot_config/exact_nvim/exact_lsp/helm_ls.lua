local Lsp = require('utils.lsp')

return {
  cmd = { 'helm_ls', 'serve' },
  on_attach = Lsp.on_attach,
  filetypes = { 'helm', 'yaml.helm-values' },
  root_markers = { 'Chart.yaml' },
  capabilities = {
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true,
      },
    },
  },
}
