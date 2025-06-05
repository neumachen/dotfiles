-----------------------------------------------------------------------------//
-- Plugin Manager {{{1
-----------------------------------------------------------------------------//
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

local specs = { { import = 'plugins' }, { import = 'langs' } }
-- Load extra plugins base on vim.g.enable_extra_plugins and merge to specs
local extra_plugins = vim.g.enable_extra_plugins -- e.g: { "no-neck-pain", "nvim-eslint" }
if extra_plugins then
  for _, plugin in ipairs(vim.g.enable_extra_plugins) do
    table.insert(specs, {
      import = 'plugins.extra.' .. plugin,
    })
  end
end
-----------------------------------------------------------------------------//
-- $NVIM {{{1
-----------------------------------------------------------------------------//
-- NOTE: this must happen after the lazy path is setup
-- If opening from inside neovim terminal then do not load other plugins
if vim.env.NVIM then return require('lazy').setup({ { 'willothy/flatten.nvim', config = true } }) end
-----------------------------------------------------------------------------//
-- lazy.nvim configuration {{{1
-----------------------------------------------------------------------------//
-- Setup lazy.nvim
require('lazy').setup({
  spec = {
    { import = 'plugins', cond = function() return not vim.g.vscode end },
    { import = 'vscode.plugins', cond = function() return vim.g.vscode end },
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
-----------------------------------------------------------------------------//
-- vim:foldmethod=marker
