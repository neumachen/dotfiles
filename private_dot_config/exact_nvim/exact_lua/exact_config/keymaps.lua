local map = vim.keymap.set

map(
  { 'n', 'v' },
  '<localleader>;',
  ':',
  { desc = 'Command Line Without Colon' }
)
map(
  { 'n', 'v' },
  '<localleader><localleader>;',
  '@:',
  { desc = 'Replay Recent Command Without Colon' }
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

-- LSP hover (use native ^ and $ for line start/end)
map('n', 'gh', vim.lsp.buf.hover, { desc = 'LSP Hover Documentation' })

-- buffers (cycling handled by bufferline.lua)
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
map('i', 'jk', '<esc>', { desc = 'Exit Insert Mode' })

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
map('i', ',', ',<c-g>u', { desc = 'Comma (undo point)' })
map('i', '.', '.<c-g>u', { desc = 'Period (undo point)' })
map('i', ';', ';<c-g>u', { desc = 'Semicolon (undo point)' })

-- Save file with notification (Ctrl-S in all relevant modes)
map({ 'n', 'i', 'v', 'x', 's' }, '<C-s>', function()
  -- Guard: terminal buffers cannot be written
  if vim.bo.buftype == 'terminal' then return end

  -- Guard: read-only buffers
  if vim.bo.readonly then
    vim.notify('  Buffer is read-only', vim.log.levels.WARN)
    return
  end

  -- Guard: special non-file buffers (nofile, prompt, help, etc.)
  if vim.bo.buftype ~= '' then return end

  -- Only write (and notify) when there are actual unsaved changes
  if vim.bo.modified then
    vim.cmd.write()
    vim.notify('  File saved', vim.log.levels.INFO)
  end
end, { desc = 'Save File' })

-- keywordprg
map('n', '<leader>K', '<cmd>norm! K<cr>', { desc = 'Keywordprg' })

-- better indenting
map('v', '<', '<gv', { desc = 'Dedent and keep selection' })
map('v', '>', '>gv', { desc = 'Indent and keep selection' })

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
map('t', '<C-/>', '<cmd>close<cr>', { desc = 'Hide Terminal' })
map('t', '<c-_>', '<cmd>close<cr>', { desc = 'which_key_ignore' })
-- Terminal window navigation handled by smart-splits.lua

-- windows
map('n', '<leader>ww', '<C-W>p', { desc = 'Other Window', remap = true })
map('n', '<leader>wd', '<C-W>c', { desc = 'Delete Window', remap = true })
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
--
-- NOTE: These mappings intentionally override Vim defaults with different behavior:
--   zv: Vim default opens folds to show cursor; here it closes all folds except current
--   zj: Vim default moves to next fold; here it closes current fold and opens next
--   zk: Vim default moves to prev fold; here it closes current fold and opens previous
--   zO: Vim default opens folds recursively under cursor; here it opens from top-level

-- Close all folds except the current one (overrides default zv)
map('n', 'zv', 'zMzvzz', {
  desc = 'Close All Folds Except Current',
})

-- Close current fold, open next fold (overrides default zj)
map('n', 'zj', 'zcjzOzz', {
  desc = 'Close Current Fold, Open Next',
})

-- Close current fold, open previous fold (overrides default zk)
map('n', 'zk', 'zckzOzz', {
  desc = 'Close Current Fold, Open Previous',
})

-- Toggle fold under cursor, or insert space if no fold
map('n', '<space><space>', [[@=(foldlevel('.')?'za':"\<Space>")<CR>]], {
  desc = 'Toggle Fold Under Cursor',
})

-- Refocus folds: close all, open current, center
map('n', '<localleader>z', [[zMzvzz]], { desc = 'Refocus Folds and Center' })

-- Open top-level fold recursively (overrides default zO)
map('n', 'zO', [[zCzO]], {
  desc = 'Recursively Open Top Level Fold',
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

-- Fix Spell checking
map('n', 'z0', '1z=', {
  desc = 'Fix Word Under Cursor',
})

map(
  'n',
  '<leader>uS',
  "<cmd>lua require('utils.cspell').add_word_to_c_spell_dictionary()<CR>",
  { noremap = true, silent = true, desc = 'Add Unknown to Cspell Dictionary' }
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
end, { desc = 'Replace Selected Char(s) in Buffer' })
