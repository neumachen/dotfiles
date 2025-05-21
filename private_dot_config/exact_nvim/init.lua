----------------------------------------------------------------------------------------------------
--  _____  ___    ___      ___
-- (\"   \|"  \  |"  \    /"  |
-- |.\\   \    |  \   \  //   |
-- |: \.   \\  |  /\\  \/.    |  neumachen's dotfiles
-- |.  \    \. | |: \.        |  https://gihtub.com/neumachen/dotfiles
-- |    \    \ | |.  \    /:  |
--  \___|\____\) |___|\__/|___|
--
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- Leader bindings
----------------------------------------------------------------------------------------------------
vim.g.mapleader = ',' -- Remap leader key
vim.g.maplocalleader = ' ' -- Local leader is <Space>
----------------------------------------------------------------------------------------------------
vim.g.os = vim.uv.os_uname().sysname
vim.g.open_command = vim.g.os == 'Darwin' and 'open' or 'xdg-open'
vim.g.dotfiles_dir = vim.env.DOTFILES_DIR
vim.g.vim_dir = vim.fn.expand('~/.config/nvim')
vim.g.dev_workspace_root = vim.env.DEV_WORKSPACE_ROOT
vim.g.vcs_repositories_dir = vim.env.VCS_REPOSITORIES_DIR
vim.g.denkwerkstatt_dir = vim.env.DENKWERKSTATT_DIR
vim.g.wissensspeicher_dir = vim.env.WISSENSSPEICHER_DIR

----------------------------------------------------------------------------------------------------
if vim.loader then vim.loader.enable() end

if vim.g.vscode then
  ----------------------------------------------------------------------------------------------------
  -- GUI
  ----------------------------------------------------------------------------------------------------
  require('config.vscode')
else
  ----------------------------------------------------------------------------------------------------
  -- Global namespace
  ----------------------------------------------------------------------------------------------------
  local namespace = {
    ui = {
      winbar = { enable = false },
      statuscolumn = { enable = true },
      statusline = { enable = true },
    },
    -- some vim mappings require a mixture of commandline commands and function calls
    -- this table is place to store lua functions to be called in those mappings
    mappings = { enable = true },
  }

  -- This table is a globally accessible store to facilitating accessing
  -- helper functions and variables throughout my config
  _G.config = config or namespace
  _G.map = vim.keymap.set
  _G.P = vim.print
  ----------------------------------------------------------------------------------------------------
  -- TUI
  ----------------------------------------------------------------------------------------------------
  -- Order matters here as globals needs to be instantiated first etc.
  require('config.globals')
  require('config.highlights')
  require('config.ui')
  require('config.settings')
end

----------------------------------------------------------------------------------------------------
vim.g.border = not vim.g.vscode and vim.g.border or 'single'
------------------------------------------------------------------------------------------------------
-- Plugins
------------------------------------------------------------------------------------------------------
local data = vim.fn.stdpath('data')
local lazypath = data .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    '--single-branch',
    'https://github.com/folke/lazy.nvim.git',
    lazypath,
  })
  vim.notify('Installed lazy.nvim')
end
vim.opt.runtimepath:prepend(lazypath)
----------------------------------------------------------------------------------------------------
--  $NVIM
----------------------------------------------------------------------------------------------------
-- NOTE: this must happen after the lazy path is setup
-- If opening from inside neovim terminal then do not load other plugins
if vim.env.NVIM then return require('lazy').setup({ { 'willothy/flatten.nvim', config = true } }) end
------------------------------------------------------------------------------------------------------
require('lazy').setup({
  spec = {
    { import = 'config.plugins', cond = function() return not vim.g.vscode end },
    { import = 'config.vscode.plugins', cond = function() return vim.g.vscode end },
  },
  defaults = { lazy = false },
  concurrency = vim.uv.available_parallelism() * 2,
  ui = { border = vim.g.border },
  checker = {
    concurrency = 15,
    enabled = true,
    notify = true,
    frequency = 3600, -- check for updates every hour
  },
  change_detection = {
    -- automatically check for config file changes and reload the ui
    enabled = true,
    notify = true, -- get a notification when changes are found
  },
  performance = {
    rtp = {
      paths = { data .. '/site' },
      disabled_plugins = { 'netrw', 'netrwPlugin' },
    },
  },
  install = {
    -- install missing plugins on startup. This doesn't increase startup time.
    missing = true,
    -- try to load one of these colorschemes when starting an installation during startup
    colorscheme = { 'tokyonight-storm' },
  },
  pkg = {
    enabled = true,
    cache = vim.fn.stdpath('state') .. '/lazy/pkg-cache.lua',
    versions = true, -- Honor versions in pkg sources
    -- the first package source that is found for a plugin will be used.
    sources = {
      'lazy',
      'rockspec',
      'packspec',
    },
  },
  rocks = {
    enabled = true,
    root = vim.fn.stdpath('data') .. '/lazy-rocks',
    server = 'https://nvim-neorocks.github.io/rocks-binaries/',
  },
})

------------------------------------------------------------------------------------------------------
-- Builtin Packages
------------------------------------------------------------------------------------------------------
-- cfilter plugin allows filtering down an existing quickfix list
vim.cmd.packadd('cfilter')
if not vim.g.vscode then
  map('n', '<leader>pm', '<Cmd>Lazy<CR>', { desc = 'manage' })
  ------------------------------------------------------------------------------------------------------
  -- Colour Scheme {{{1
  ------------------------------------------------------------------------------------------------------
  vim.g.high_contrast_theme = false -- set to true for themes like github_dark or night-owl
  config.pcall('theme failed to load because', vim.cmd.colorscheme, 'tokyonight-storm')
end
