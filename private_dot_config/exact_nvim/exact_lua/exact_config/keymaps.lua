local map = vim.keymap.set

map(
  { 'n', 'v' },
  '<localleader>;',
  ':',
  { desc = 'command line without colon' }
)
map(
  { 'n', 'v' },
  '<localleader><localleader>;',
  '@:',
  { desc = 'replay recent command without colon' }
)

-- Better up/down
map(
  { 'n', 'x' },
  'j',
  "v:count == 0 ? 'gj' : 'j'",
  { desc = 'Down', expr = true, silent = true }
)
map(
  { 'n', 'x' },
  '<Down>',
  "v:count == 0 ? 'gj' : 'j'",
  { desc = 'Down', expr = true, silent = true }
)
map(
  { 'n', 'x' },
  'k',
  "v:count == 0 ? 'gk' : 'k'",
  { desc = 'Up', expr = true, silent = true }
)
map(
  { 'n', 'x' },
  '<Up>',
  "v:count == 0 ? 'gk' : 'k'",
  { desc = 'Up', expr = true, silent = true }
)

-- Move Lines
local opts = { noremap = true, silent = true }

-- NORMAL mode: move current line
map(
  'n',
  '<C-A-j>',
  ':m .+1<CR>==',
  vim.tbl_extend('force', opts, { desc = 'Move line down' })
)
map(
  'n',
  '<C-A-k>',
  ':m .-2<CR>==',
  vim.tbl_extend('force', opts, { desc = 'Move line up' })
)

-- INSERT mode: move current line, return to insert at same spot
map(
  'i',
  '<C-A-j>',
  '<Esc>:m .+1<CR>==gi',
  vim.tbl_extend('force', opts, { desc = 'Move line down' })
)
map(
  'i',
  '<C-A-k>',
  '<Esc>:m .-2<CR>==gi',
  vim.tbl_extend('force', opts, { desc = 'Move line up' })
)

-- VISUAL mode: move selected lines as a block
map(
  'v',
  '<C-A-j>',
  ":m '>+1<CR>gv=gv",
  vim.tbl_extend('force', opts, { desc = 'Move block down' })
)
map(
  'v',
  '<C-A-k>',
  ":m '<-2<CR>gv=gv",
  vim.tbl_extend('force', opts, { desc = 'Move block up' })
)

-- Goto
map('n', 'gl', '$', { desc = 'Go to end of line' })
map('n', 'gh', '^', { desc = 'go to start of line' })

-- buffers
map('n', '<s-h>', '<cmd>bprevious<cr>', { desc = 'prev buffer' })
map('n', '<s-l>', '<cmd>bnext<cr>', { desc = 'next buffer' })
map('n', '[b', '<cmd>bprevious<cr>', { desc = 'prev buffer' })
map('n', ']b', '<cmd>bnext<cr>', { desc = 'next buffer' })
map('n', '<leader>bb', '<cmd>e #<cr>', { desc = 'Switch to Other Buffer' })
map('n', '<leader>`', '<cmd>e #<cr>', { desc = 'Switch to Other Buffer' })

-- Clear search with <esc>
map(
  { 'i', 'n' },
  '<esc>',
  '<cmd>noh<cr><esc>',
  { desc = 'Escape and Clear hlsearch' }
)

-- jk to escape in insert mode
map('i', 'jk', '<esc>', { desc = 'Exit insert mode' })

-- Clear search, diff update and redraw
-- taken from runtime/lua/_editor.lua
map(
  'n',
  '<leader>ur',
  '<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>',
  { desc = 'Redraw / Clear hlsearch / Diff Update' }
)

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
map(
  'n',
  'n',
  "'Nn'[v:searchforward].'zv'",
  { expr = true, desc = 'Next Search Result' }
)
map(
  'x',
  'n',
  "'Nn'[v:searchforward]",
  { expr = true, desc = 'Next Search Result' }
)
map(
  'o',
  'n',
  "'Nn'[v:searchforward]",
  { expr = true, desc = 'Next Search Result' }
)
map(
  'n',
  'N',
  "'nN'[v:searchforward].'zv'",
  { expr = true, desc = 'Prev Search Result' }
)
map(
  'x',
  'N',
  "'nN'[v:searchforward]",
  { expr = true, desc = 'Prev Search Result' }
)
map(
  'o',
  'N',
  "'nN'[v:searchforward]",
  { expr = true, desc = 'Prev Search Result' }
)

-- Add undo break-points
map('i', ',', ',<c-g>u')
map('i', '.', '.<c-g>u')
map('i', ';', ';<c-g>u')

-- save file
map({ 'i', 'x', 'n', 's' }, '<F4>', '<cmd>w<cr><esc>', { desc = 'Save File' })

-- keywordprg
map('n', '<leader>K', '<cmd>norm! K<cr>', { desc = 'Keywordprg' })

-- better indenting
map('v', '<', '<gv')
map('v', '>', '>gv')

-- commenting
map(
  'n',
  'gco',
  'o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>',
  { desc = 'Add Comment Below' }
)
map(
  'n',
  'gcO',
  'O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>',
  { desc = 'Add Comment Above' }
)

-- lazy
map('n', '<leader>zz', '<cmd>Lazy<cr>', { desc = 'Lazy' })

-- new file
map('n', '<leader>fn', '<cmd>enew<cr>', { desc = 'New File' })

-- location list
map('n', '<leader>xl', function()
  local success, err = pcall(
    vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 and vim.cmd.lclose
      or vim.cmd.lopen
  )
  if not success and err then vim.notify(err, vim.log.levels.ERROR) end
end, { desc = 'Location List' })
-- quickfix list
map('n', '<leader>xq', function()
  local success, err = pcall(
    vim.fn.getqflist({ winid = 0 }).winid ~= 0 and vim.cmd.cclose
      or vim.cmd.copen
  )
  if not success and err then vim.notify(err, vim.log.levels.ERROR) end
end, { desc = 'Quickfix List' })

map('n', '[q', vim.cmd.cprev, { desc = 'Previous Quickfix' })
map('n', ']q', vim.cmd.cnext, { desc = 'Next Quickfix' })

-- diagnostic
local diagnostic_goto = function(next, severity)
  local go = next and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
  severity = severity and vim.diagnostic.severity[severity] or nil
  return function() go({ severity = severity }) end
end
map('n', '<leader>cd', vim.diagnostic.open_float, { desc = 'Line Diagnostics' })
map('n', ']d', diagnostic_goto(true), { desc = 'Next Diagnostic' })
map('n', '[d', diagnostic_goto(false), { desc = 'Prev Diagnostic' })
map('n', ']e', diagnostic_goto(true, 'ERROR'), { desc = 'Next Error' })
map('n', '[e', diagnostic_goto(false, 'ERROR'), { desc = 'Prev Error' })
map('n', ']w', diagnostic_goto(true, 'WARN'), { desc = 'Next Warning' })
map('n', '[w', diagnostic_goto(false, 'WARN'), { desc = 'Prev Warning' })

-- quit
map('n', '<leader>qq', '<cmd>qa<cr>', { desc = 'Quit All' })

-- highlights under cursor
map('n', '<leader>ui', vim.show_pos, { desc = 'Inspect Pos' })
map('n', '<leader>uI', '<cmd>InspectTree<cr>', { desc = 'Inspect Tree' })

-- Terminal Mappings
map('t', '<esc><esc>', '<c-\\><c-n>', { desc = 'Enter Normal Mode' })
map('t', '<C-h>', '<cmd>wincmd h<cr>', { desc = 'Go to Left Window' })
map('t', '<C-j>', '<cmd>wincmd j<cr>', { desc = 'Go to Lower Window' })
map('t', '<C-k>', '<cmd>wincmd k<cr>', { desc = 'Go to Upper Window' })
map('t', '<C-l>', '<cmd>wincmd l<cr>', { desc = 'Go to Right Window' })
map('t', '<C-/>', '<cmd>close<cr>', { desc = 'Hide Terminal' })
map('t', '<c-_>', '<cmd>close<cr>', { desc = 'which_key_ignore' })

-- windows
map('n', '<leader>ww', '<C-W>p', { desc = 'Other Window', remap = true })
map('n', '<leader>wd', '<C-W>c', { desc = 'Delete Window', remap = true })
map('n', '<leader>w-', '<C-W>s', { desc = 'Split Window Below', remap = true })
map('n', '<leader>w|', '<C-W>v', { desc = 'Split Window Right', remap = true })
map('n', '<leader>-', '<C-W>s', { desc = 'Split Window Below', remap = true })
map('n', '<leader>|', '<C-W>v', { desc = 'Split Window Right', remap = true })

-- tabs
map('n', '<leader><tab>l', '<cmd>tablast<cr>', { desc = 'Last Tab' })
map('n', '<leader><tab>o', '<cmd>tabonly<cr>', { desc = 'Close Other Tabs' })
map('n', '<leader><tab>f', '<cmd>tabfirst<cr>', { desc = 'First Tab' })
map('n', '<leader><tab><tab>', '<cmd>tabnew<cr>', { desc = 'New Tab' })
map('n', '<leader><tab>]', '<cmd>tabnext<cr>', { desc = 'Next Tab' })
map('n', '<leader><tab>d', '<cmd>tabclose<cr>', { desc = 'Close Tab' })
map('n', '<leader><tab>[', '<cmd>tabprevious<cr>', { desc = 'Previous Tab' })

vim.api.nvim_create_user_command('FormatDisable', function(args)
  if args.bang then
    -- FormatDisable! will disable formatting just for this buffer
    vim.b.disable_autoformat = true
  else
    vim.g.disable_autoformat = true
  end
end, {
  desc = 'Disable autoformat-on-save',
  bang = true,
})
vim.api.nvim_create_user_command('FormatEnable', function()
  vim.b.disable_autoformat = false
  vim.g.disable_autoformat = false
end, {
  desc = 'Re-enable autoformat-on-save',
})

-- Define a global variable to enable/disable autoformat
local auto_format = true
map('n', '<leader>uf', function()
  auto_format = not auto_format
  if auto_format then
    vim.cmd('FormatEnable')
  else
    vim.cmd('FormatDisable')
  end
end, { desc = 'Toggle Autoformat' })

-- ------------------------------------------------------------------------- }}}
-- {{{ Folding commands.

-- Close all fold except the current one.
map('n', 'zv', 'zMzvzz', {
  desc = 'Close all folds except the current one',
})

-- Close current fold when open. Always open next fold.
map('n', 'zj', 'zcjzOzz', {
  desc = 'Close current fold when open. Always open next fold.',
})

-- Close current fold when open. Always open previous fold.
map('n', 'zk', 'zckzOzz', {
  desc = 'Close current fold when open. Always open previous fold.',
})

-- Evaluates whether there is a fold on the current line if so unfold it else return a normal space
map('n', '<space><space>', [[@=(foldlevel('.')?'za':"\<Space>")<CR>]], {
  desc = 'toggle fold under cursor',
})

-- Refocus folds
map('n', '<localleader>z', [[zMzvzz]], { desc = 'center viewport' })

-- Make zO recursively open whatever top level fold we're in, no matter where the
-- cursor happens to be.
map('n', 'zO', [[zCzO]], {
  desc = 'recursively open current top level fold',
})

-- Refer [FAQ - Neovide](https://neovide.dev/faq.html#how-can-i-use-cmd-ccmd-v-to-copy-and-paste)
if vim.g.neovide then
  vim.keymap.set('n', '<D-s>', ':w<CR>') -- Save
  vim.keymap.set('v', '<D-c>', '"+y') -- Copy
  vim.keymap.set({ 'n', 'v' }, '<D-v>', '"+P') -- Paste normal and visual mode
  vim.keymap.set({ 'i', 'c' }, '<D-v>', '<C-R>+') -- Paste insert and command mode
  vim.keymap.set('t', '<D-v>', [[<C-\><C-N>"+P]]) -- Paste terminal mode  vim.keymap.set("n", "<D-s>", ":w<CR>") -- Save
end

-- Silent keymap option
local opts = { silent = true }

-- Better paste
-- remap "p" in visual mode to delete the highlighted text without overwriting your yanked/copied text, and then paste the content from the unnamed register.
map('v', 'p', '"_dP', opts)

-- Copy whole file content to clipboard with C-c
map('n', '<C-c>', ':%y+<CR>', opts)

-- Select all text in buffer with Alt-a
map(
  'n',
  '<A-a>',
  'ggVG',
  { noremap = true, silent = true, desc = 'Select all' }
)

-- Visual --
-- Stay in indent mode
map('v', '<', '<gv', opts)
map('v', '>', '>gv', opts)

-- Easier access to beginning and end of lines
map('n', '<A-h>', '^', {
  desc = 'Go to start of line',
  silent = true,
})
map('n', '<A-l>', '$', {
  desc = 'Go to end of line',
  silent = true,
})

-- Fix Spell checking
map('n', 'z0', '1z=', {
  desc = 'Fix world under cursor',
})

map(
  'n',
  '<leader>uS',
  "<cmd>lua require('utils.cspell').add_word_to_c_spell_dictionary()<CR>",
  { noremap = true, silent = true, desc = 'Add unknown to cspell dictionary' }
)

-- Replace selected character(s) in buffer (handles any encoding)
-- Select character(s) in visual mode, press <leader>rc, enter replacement
map('v', '<localleader>rc', function()
  -- Yank the selected text
  vim.cmd('normal! "zy')
  local selected = vim.fn.getreg('z')

  if selected == '' then
    vim.notify('No text selected', vim.log.levels.WARN)
    return
  end

  -- Show character info for reference
  local char_codes = {}
  for i = 1, vim.fn.strchars(selected) do
    local char = vim.fn.strcharpart(selected, i - 1, 1)
    local nr = vim.fn.char2nr(char)
    table.insert(char_codes, string.format('%s (U+%04X)', char, nr))
  end
  vim.notify(
    'Selected: ' .. table.concat(char_codes, ', '),
    vim.log.levels.INFO
  )

  -- Prompt for replacement
  vim.ui.input({ prompt = 'Replace with: ' }, function(replacement)
    if replacement == nil then
      vim.notify('Replacement cancelled', vim.log.levels.INFO)
      return
    end

    -- Escape special characters for use in substitution
    local escaped_selected = vim.fn.escape(selected, '/\\.*$^~[]')
    local escaped_replacement = vim.fn.escape(replacement, '/\\&~')

    -- Perform the substitution
    local cmd =
      string.format('%%s/%s/%s/g', escaped_selected, escaped_replacement)
    local ok, err = pcall(vim.cmd, cmd)

    if ok then
      vim.notify(
        string.format('Replaced "%s" with "%s"', selected, replacement),
        vim.log.levels.INFO
      )
    else
      vim.notify('Replacement failed: ' .. tostring(err), vim.log.levels.ERROR)
    end
  end)
end, { desc = 'Replace selected char(s) in buffer' })
