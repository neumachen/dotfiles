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

-- Project-local settings are loaded via Neovim's built-in `exrc` (enabled in
-- config.settings). Drop a `.nvim.lua` in the project root (or any ancestor
-- of the file being edited) and run `:trust` once to authorize it.

require('config.autocmds')
require('config.lazy')
require('config.keymaps')
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
  ext.pcall(
    'theme failed to load because',
    vim.cmd.colorscheme,
    'tokyonight-storm'
  )

  local ts_server = vim.g.lsp_typescript_server or 'ts_ls' -- "ts_ls" or "vtsls" for TypeScript

  -- Dynamically discover LSP servers from the lsp directory
  local lsp_dir = vim.fn.stdpath('config') .. '/lsp'
  local lsp_servers = {}

  -- Get all .lua files in the lsp directory
  for name, type in vim.fs.dir(lsp_dir) do
    if type == 'file' and name:match('%.lua$') then
      local server_name = name:gsub('%.lua$', '')
      table.insert(lsp_servers, server_name)
    end
  end

  -- Remove ts_ls and vtsls from auto-discovered list since we handle TypeScript server selection dynamically
  lsp_servers = vim.tbl_filter(
    function(server) return server ~= 'ts_ls' and server ~= 'vtsls' end,
    lsp_servers
  )

  -- Add the selected TypeScript server
  table.insert(lsp_servers, ts_server)

  -- Enable LSP servers for Neovim 0.11+
  vim.lsp.enable(lsp_servers)

  -- Load Lsp on-demand, e.g: eslint is disable by default
  -- e.g: We could enable eslint by set vim.g.lsp_on_demands = {"eslint"}
  if vim.g.lsp_on_demands then vim.lsp.enable(vim.g.lsp_on_demands) end
end
-----------------------------------------------------------------------------//
-- vim:foldmethod=marker
