local Lsp = require('utils.lsp')

---@diagnostic disable: missing-fields, inject-field
---@type vim.lsp.Client
return {
  before_init = function(_, client_config) client_config.settings.yaml.schemas = require('schemastore').yaml.schemas() end,
  cmd = { 'yaml-language-server', '--stdio' },
  filetypes = { 'yaml', 'yaml.docker-compose', 'yaml.gitlab', 'yaml.helm-values' },
  root_markers = { '.git' },
  on_attach = Lsp.on_attach,
  settings = {
    redhat = { telemetry = { enabled = false } },
    yaml = {
      keyOrdering = false,
      format = {
        enable = false, -- conform and prettier are better
      },
      validate = true,
      schemaStore = {
        -- Must disable built-in schemaStore support to use schemas from SchemaStore.nvim plugin
        enable = false,
        -- Avoid TypeError: Cannot read properties of undefined (reading 'length')
        url = '',
      },
    },
  },
}
