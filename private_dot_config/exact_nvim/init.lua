-----------------------------------------------------------------------------//
-- Initialize {{{1
-----------------------------------------------------------------------------//
--  _____  ___    ___      ___
-- (\"   \|"  \  |"  \    /"  |
-- |.\\   \    |  \   \  //   |
-- |: \.   \\  |  /\\  \/.    |  neumachen's dotfiles
-- |.  \    \. | |: \.        |  https://gihtub.com/neumachen/dotfiles
-- |    \    \ | |.  \    /:  |
--  \___|\____\) |___|\__/|___|
-----------------------------------------------------------------------------//
require('config.settings')
require('config.autocmds')
require('config.lazy')
require('config.key_mappings')
-----------------------------------------------------------------------------//
-- LazyNVIM {{{1
-----------------------------------------------------------------------------//
-- Only load the theme if not in VSCode
if vim.g.vscode then
  -- Trigger vscode keymap
  local pattern = 'NvimIdeKeymaps'
  vim.api.nvim_exec_autocmds('User', { pattern = pattern, modeline = false })
else
  local ext = require('utils.ext')
  -- Load the theme
  ext.pcall('theme failed to load because', vim.cmd.colorscheme, 'catppuccin-macchiato')

  local ts_server = vim.g.lsp_typescript_server or 'ts_ls' -- "ts_ls" or "vtsls" for TypeScript

  -- Enable LSP servers for Neovim 0.11+
  vim.lsp.enable({
    ts_server,
    'lua_ls', -- Lua
    'biome', -- Biome = Eslint + Prettier
    'json', -- JSON
    'pyright', -- Python
    'gopls', -- Go
    'tailwindcss', -- Tailwind CSS
  })

  -- Load Lsp on-demand, e.g: eslint is disable by default
  -- e.g: We could enable eslint by set vim.g.lsp_on_demands = {"eslint"}
  if vim.g.lsp_on_demands then vim.lsp.enable(vim.g.lsp_on_demands) end
end
-----------------------------------------------------------------------------//
-- vim:foldmethod=marker
