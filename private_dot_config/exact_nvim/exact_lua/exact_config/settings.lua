local opt, fn = vim.opt, vim.fn

-- Prepend mise shims to PATH
vim.env.PATH = vim.env.HOME .. '/.local/share/mise/shims:' .. vim.env.PATH
-----------------------------------------------------------------------------//
-- Leader Bindings {{{1
-----------------------------------------------------------------------------//
vim.g.mapleader = ',' -- Remap leader key
vim.g.maplocalleader = ' ' -- Local leader is <Space>
-----------------------------------------------------------------------------//
-- Disable providers {{{1
-----------------------------------------------------------------------------//
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
-- Borrow those settings from LazyVim
opt.autowrite = true -- Enable auto write
-- only set clipboard if not in ssh, to make sure the OSC 52
-- integration works automatically. Requires Neovim >= 0.10.0
opt.clipboard = vim.env.SSH_TTY and '' or 'unnamedplus' -- Sync with system clipboard
-----------------------------------------------------------------------------//
-- Message output on vim actions {{{1
-----------------------------------------------------------------------------//
opt.shortmess = {
  t = true, -- truncate file messages at start
  A = true, -- ignore annoying swap file messages
  o = true, -- file-read message overwrites previous
  O = true, -- file-read message overwrites previous
  T = true, -- truncate non-file messages in middle
  F = true, -- Don't give file info when editing a file, NOTE: this breaks autocommand meages
  s = true,
  c = true,
  W = true, -- Don't show [w] or written when writing
}
-----------------------------------------------------------------------------//
-- Timings {{{1
-----------------------------------------------------------------------------//
opt.updatetime = 200
opt.timeout = true
opt.timeoutlen = vim.g.vscode and 1000 or 300 -- Lower than default (1000) to quickly trigger which-key
-----------------------------------------------------------------------------//
-- Window splitting and buffers {{{1
-----------------------------------------------------------------------------//
opt.eadirection = 'hor'
opt.splitbelow = true
opt.splitkeep = 'screen'
opt.splitright = true
-- exclude usetab as we do not want to jump to buffers in already open tabs
-- do not use split or vsplit to ensure we don't open any new windows
opt.switchbuf = 'useopen,uselast'
opt.fillchars = {
  eob = ' ', -- suppress ~ at EndOfBuffer
  diff = '╱', -- alternatives = ⣿ ░ ─
  msgsep = ' ', -- alternatives: ‾ ─
  fold = ' ',
  foldopen = '▽', -- '▼'
  foldclose = '▷', -- '▶'
  foldsep = ' ',
}
-----------------------------------------------------------------------------//
-- Diff {{{1
-----------------------------------------------------------------------------//
-- Use in vertical diff mode, blank lines to keep sides aligned, Ignore whitespace changes
opt.diffopt = opt.diffopt
  + {
    'vertical',
    'iwhite',
    'hiddenoff',
    'foldcolumn:0',
    'context:4',
    'algorithm:histogram',
    'indent-heuristic',
    'linematch:60',
  }
-----------------------------------------------------------------------------//
-- Format Options {{{1
-----------------------------------------------------------------------------//
opt.formatoptions = {
  ['1'] = true,
  ['2'] = true, -- Use indent from 2nd line of a paragraph
  q = true, -- continue comments with gq"
  c = true, -- Auto-wrap comments using textwidth
  r = true, -- Continue comments when pressing Enter
  n = true, -- Recognize numbered lists
  t = false, -- autowrap lines using text width value
  j = true, -- remove a comment leader when joining lines.
  -- Only break if the line was not longer than 'textwidth' when the insert
  -- started and only at a white character that has been entered during the
  -- current insert command.
  l = true,
  v = true,
}
-----------------------------------------------------------------------------//
-- Folds {{{1
-----------------------------------------------------------------------------//
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldmethod = 'expr'
opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
opt.foldtext = ''
-----------------------------------------------------------------------------//
-- Grepprg {{{1
-----------------------------------------------------------------------------//
-- Use faster grep alternatives if possible
opt.grepprg = [[rg --glob "!.git" --no-heading --vimgrep --follow $*]]
opt.grepformat = opt.grepformat ^ { '%f:%l:%c:%m' }
-----------------------------------------------------------------------------//
-- Wild and file globbing stuff in command mode {{{1
-----------------------------------------------------------------------------//
opt.wildcharm = ('\t'):byte()
opt.wildmode = 'list:full' -- Shows a menu bar as opposed to an enormous list
opt.wildignorecase = true -- Ignore case when completing file names and directories
opt.wildignore = {
  '*.avi',
  '*.class',
  '*.dll',
  '*.gif',
  '*.ico',
  '*.jar',
  '*.jpeg',
  '*.jpg',
  '*.o',
  '*.obj',
  '*.png',
  '*.pyc',
  '*.rbc',
  '*.swp',
  '*.wav',
  '.lock',
  '.DS_Store',
  'tags.lock',
}
opt.wildoptions = { 'pum', 'fuzzy' }
opt.pumblend = 0 -- Make popup window translucent
-----------------------------------------------------------------------------//
-- Display {{{1
-----------------------------------------------------------------------------//
opt.colorcolumn = '+1'
opt.conceallevel = 2
opt.breakindentopt = 'sbr'
opt.linebreak = true -- Lines wrap at words rather than random characters
opt.signcolumn = 'yes:1'
opt.ruler = false
opt.cmdheight = 0
opt.showbreak = [[↪ ]] -- Options include -> '…', '↳ ', '→','↪ '
-----------------------------------------------------------------------------//
-- List chars {{{1
-----------------------------------------------------------------------------//
opt.list = true -- invisible chars
opt.listchars = {
  eol = nil,
  tab = '  ', -- Alternatives: '▷▷',
  extends = '…', -- Alternatives: … » ›
  precedes = '░', -- Alternatives: … « ‹
  trail = '•', -- BULLET (U+2022, UTF-8: E2 80 A2)
}
-----------------------------------------------------------------------------//
-- Indentation
-----------------------------------------------------------------------------//
opt.autoindent = true
opt.expandtab = true -- Convert tabs to spaces globally
opt.shiftround = true
opt.shiftwidth = 2
opt.textwidth = 80
opt.wrap = false
opt.wrapmargin = 2
-----------------------------------------------------------------------------//
opt.autowriteall = true -- Automatically :write before running commands and changing files
opt.completeopt = 'menu,menuone,noselect,fuzzy'
opt.confirm = true -- Make vim prompt me to save before doing destructive things
opt.guifont = 'CartographCF Nerd Font:h14'
opt.hlsearch = true
opt.laststatus = 3
opt.inccommand = 'split'
opt.pumheight = 15
opt.termguicolors = true
-----------------------------------------------------------------------------//
opt.number = true
opt.relativenumber = true
-----------------------------------------------------------------------------//
-- Emoji {{{1
-----------------------------------------------------------------------------//
-- emoji is true by default but makes (n)vim treat all emoji as double width
-- which breaks rendering so we turn this off.
-- CREDIT: https://www.youtube.com/watch?v=F91VWOelFNE
opt.emoji = false
-----------------------------------------------------------------------------//
-- Cursor {{{1
-----------------------------------------------------------------------------//
-- This is from the help docs, it enables mode shapes, "Cursor" highlight, and blinking
opt.guicursor = {
  'n-v-c-sm:block-Cursor',
  'i-ci-ve:ver25-iCursor',
  'r-cr-o:hor20-Cursor',
  'a:blinkon0',
}
opt.cursorlineopt = { 'both' }
-----------------------------------------------------------------------------//
-- Title {{{1
-----------------------------------------------------------------------------//
opt.titleold = fn.fnamemodify(os.getenv('SHELL'), ':t') or ''
opt.title = true
opt.titlelen = 80
-----------------------------------------------------------------------------//
-- Utilities {{{1
-----------------------------------------------------------------------------//
opt.showmode = false
-- NOTE: Don't remember
-- * help files since that will error if they are from a lazy loaded plugin
-- * folds since they are created dynamically and might be missing on startup
opt.sessionoptions = {
  'buffers',
  'curdir',
  'folds',
  'globals',
  'help',
  'tabpages',
  'terminal',
  'winpos',
  'winsize',
}
opt.viewoptions = { 'cursor', 'folds' } -- save/restore just these (with `:{mk,load}view`)
opt.virtualedit = 'block' -- Allow cursor to move where there is no text in visual block mode
-----------------------------------------------------------------------------//
-- Jumplist
-----------------------------------------------------------------------------//
opt.jumpoptions = { 'stack' } -- make the jumplist behave like a browser stack
-------------------------------------------------------------------------------
-- BACKUP AND SWAPS {{{
-------------------------------------------------------------------------------
opt.backup = false
opt.swapfile = false
opt.undofile = true
opt.undolevels = 10000
--}}}
-----------------------------------------------------------------------------//
-- Match and search {{{1
-----------------------------------------------------------------------------//
opt.ignorecase = true
opt.scrolloff = 9
opt.sidescroll = 1
opt.sidescrolloff = 10
opt.smartcase = true
opt.wrapscan = true -- Searches wrap around the end of the file
-----------------------------------------------------------------------------//
-- Spelling {{{1
-----------------------------------------------------------------------------//
opt.spellcapcheck = '' -- don't check for capital letters at start of sentence
opt.spelllang = { 'en' }
opt.spelloptions:append({ 'camel', 'noplainbuffer' })
opt.spellsuggest:prepend({ 12 })
-----------------------------------------------------------------------------//
-- Mouse {{{1
-----------------------------------------------------------------------------//
opt.mousefocus = true
opt.mousemoveevent = true
opt.mousescroll = { 'ver:1', 'hor:6' }
-----------------------------------------------------------------------------//
-- Diagnostic Settings {{{1
-----------------------------------------------------------------------------//
local diagnostics = {
  Error = ' ',
  Warn = ' ',
  Hint = ' ',
  Info = ' ',
}
vim.diagnostic.config({
  underline = true,
  update_in_insert = false,
  virtual_text = {
    spacing = 4,
    source = 'if_many',
    prefix = '●',
  },
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = diagnostics.Error,
      [vim.diagnostic.severity.WARN] = diagnostics.Warn,
      [vim.diagnostic.severity.HINT] = diagnostics.Hint,
      [vim.diagnostic.severity.INFO] = diagnostics.Info,
    },
  },
})

-- Setup options for Neovide
if vim.g.neovide then
  vim.g.neovide_hide_mouse_when_typing = true
  vim.g.neovide_cursor_antialiasing = false
  vim.g.neovide_input_macos_option_key_is_meta = 'only_left'
  vim.g.neovide_input_ime = true
end
-----------------------------------------------------------------------------//
-- vim:foldmethod=marker
