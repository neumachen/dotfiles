---@diagnostic disable: inject-field
---@type vim.lsp.Config
return {
  -- NOTE: npm i -g vscode-langservers-extracted
  cmd = { 'vscode-json-language-server', '--stdio' },
  filetypes = { 'json', 'jsonc' },
  root_markers = { '.git' },
  settings = {
    json = {
      validate = {
        enabled = true,
      },
    },
  },
  before_init = function(_, config)
    -- can't assign new table because of
    -- https://github.com/neovim/neovim/issues/27740#issuecomment-1978629315
    config.settings.json.schemas = require('schemastore').json.schemas()
  end,
}
