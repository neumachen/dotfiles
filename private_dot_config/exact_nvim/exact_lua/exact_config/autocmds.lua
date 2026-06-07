local function augroup(name)
  return vim.api.nvim_create_augroup('neumachenvim_' .. name, { clear = true })
end

-- Check if we need to reload the file when it changed.
-- Paired with `vim.o.autoread = true` in config/settings.lua.
-- CursorHold uses updatetime (200ms here) so sitting idle in a buffer
-- still picks up external edits (CLI, formatters, other agents, etc.).
-- NOTE: cache the augroup id; calling augroup('checktime') twice would
-- re-create the group with { clear = true } and wipe the previous autocmd.
local checktime_group = augroup('checktime')

vim.api.nvim_create_autocmd(
  { 'FocusGained', 'TermClose', 'TermLeave', 'BufEnter', 'CursorHold' },
  {
    group = checktime_group,
    callback = function()
      if vim.o.buftype ~= 'nofile' then vim.cmd('checktime') end
    end,
  }
)

-- Notify when a buffer is reloaded because its file changed on disk.
vim.api.nvim_create_autocmd('FileChangedShellPost', {
  group = checktime_group,
  callback = function()
    vim.notify(
      'File changed on disk. Buffer reloaded.',
      vim.log.levels.INFO,
      { title = 'autoread' }
    )
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  group = augroup('highlight_yank'),
  callback = function() (vim.hl or vim.highlight).on_yank() end,
})

-- resize splits if window got resized
vim.api.nvim_create_autocmd({ 'VimResized' }, {
  group = augroup('resize_splits'),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd('tabdo wincmd =')
    vim.cmd('tabnext ' .. current_tab)
  end,
})

-- go to last loc when opening a buffer
vim.api.nvim_create_autocmd('BufReadPost', {
  group = augroup('last_loc'),
  callback = function(event)
    local exclude = { 'gitcommit' }
    local buf = event.buf
    if
      vim.tbl_contains(exclude, vim.bo[buf].filetype)
      or vim.b[buf].lazyvim_last_loc
    then
      return
    end
    vim.b[buf].lazyvim_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- close some filetypes with <q>
vim.api.nvim_create_autocmd('FileType', {
  group = augroup('close_with_q'),
  pattern = {
    'PlenaryTestPopup',
    'checkhealth',
    'dbout',
    'gitsigns-blame',
    'help',
    'lspinfo',
    'neotest-output',
    'neotest-output-panel',
    'neotest-summary',
    'notify',
    'qf',
    'spectre_panel',
    'startuptime',
    'tsplayground',
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.schedule(function()
      vim.keymap.set('n', 'q', function()
        vim.cmd('close')
        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
      end, {
        buffer = event.buf,
        silent = true,
        desc = 'Quit buffer',
      })
    end)
  end,
})

-- make it easier to close man-files when opened inline
vim.api.nvim_create_autocmd('FileType', {
  group = augroup('man_unlisted'),
  pattern = { 'man' },
  callback = function(event) vim.bo[event.buf].buflisted = false end,
})

-- wrap and check for spell in text filetypes
vim.api.nvim_create_autocmd('FileType', {
  group = augroup('wrap_spell'),
  pattern = {
    '*.txt',
    '*.tex',
    '*.typ',
    'gitcommit',
    'markdown',
    'markdown.mdc',
  },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Fix conceallevel for json files
vim.api.nvim_create_autocmd({ 'FileType' }, {
  group = augroup('json_conceal'),
  pattern = { 'json', 'jsonc', 'json5' },
  callback = function() vim.opt_local.conceallevel = 0 end,
})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
  group = augroup('auto_create_dir'),
  callback = function(event)
    if event.match:match('^%w%w+:[\\/][\\/]') then return end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
  end,
})

-- Set filetype for .env and .env.* files
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  group = augroup('env_filetype'),
  pattern = { '*.env', '.env.*' },
  callback = function() vim.opt_local.filetype = 'sh' end,
})

-- Set filetype for .hurl files
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  group = augroup('hurl_filetype'),
  pattern = { '*.hurl' },
  callback = function() vim.opt_local.filetype = 'hurl' end,
})

-- Set filetype for .toml files
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  group = augroup('toml_filetype'),
  pattern = { '*.tomg-config*' },
  callback = function() vim.opt_local.filetype = 'toml' end,
})

-- Set filetype for .ejs files
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  group = augroup('ejs_filetype'),
  pattern = { '*.ejs', '*.ejs.t' },
  callback = function() vim.opt_local.filetype = 'embedded_template' end,
})

-- Set filetype for .code-snippets files
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  group = augroup('code_snippets_filetype'),
  pattern = { '*.code-snippets' },
  callback = function() vim.opt_local.filetype = 'json' end,
})

-----------------------------------------------------------------------------//
-- Cheazmoi {{{1
-----------------------------------------------------------------------------//

local dotfiles_dir = os.getenv('DOTFILES_DIR')
if dotfiles_dir then
  vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    pattern = { dotfiles_dir .. '/*' },
    callback = function(ev)
      local bufnr = ev.buf
      local edit_watch = function()
        require('chezmoi.commands.__edit').watch(bufnr)
      end
      vim.schedule(edit_watch)
    end,
  })
end
-----------------------------------------------------------------------------//

-----------------------------------------------------------------------------//
-- LSP {{{1
-----------------------------------------------------------------------------//
local completion = vim.g.completion_mode or 'blink' -- or 'native'
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client then
      -- Built-in completion
      if
        completion == 'native'
        and client:supports_method('textDocument/completion')
      then
        vim.lsp.completion.enable(
          true,
          client.id,
          args.buf,
          { autotrigger = true }
        )
      end

      -- Inlay hints
      if client:supports_method('textDocument/inlayHints') then
        vim.lsp.inlay_hint.enable(false, { bufnr = args.buf })
      end
    end
  end,
})
-----------------------------------------------------------------------------//
-- Lazy lockfile sync back to chezmoi source {{{1
-----------------------------------------------------------------------------//
-- lazy.nvim writes lazy-lock.json to stdpath("config") (the *target* dir).
-- chezmoi only tracks the *source* dir, so the lockfile change is invisible
-- to chezmoi until a manual `chezmoi re-add`. This autocmd runs `chezmoi
-- re-add` on the lockfile automatically after any lazy operation that
-- rewrites it: LazyUpdate, LazySync, LazyInstall.
--
-- NOTE: if you ever re-introduce a lock-writing plugin manager or add other
-- lock files (e.g. package-lock.json managed by chezmoi), apply the same
-- pattern with their equivalent post-write events.
vim.api.nvim_create_autocmd('User', {
  group = augroup('lazy_lockfile_chezmoi_sync'),
  pattern = { 'LazyUpdate', 'LazySync', 'LazyInstall' },
  callback = function()
    local lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json'
    if vim.fn.filereadable(lockfile) == 0 then return end
    vim.system(
      { 'chezmoi', 're-add', lockfile },
      { text = true },
      function(result)
        if result.code == 0 then
          vim.schedule(function()
            vim.notify('lazy-lock.json synced to chezmoi source', vim.log.levels.INFO)
          end)
        else
          vim.schedule(function()
            vim.notify(
              'chezmoi re-add failed: ' .. (result.stderr or ''),
              vim.log.levels.WARN
            )
          end)
        end
      end
    )
  end,
})
-----------------------------------------------------------------------------//
-- vim:foldmethod=marker
