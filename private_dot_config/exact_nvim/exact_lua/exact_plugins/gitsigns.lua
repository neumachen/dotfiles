local cwd = vim.fn.getcwd
local map = vim.keymap.set

return {
  'lewis6991/gitsigns.nvim',
  event = { 'BufReadPre', 'BufNewFile' },
  opts = {
    signs = {
      add = { text = '┃' },
      change = { text = '┃' },
      delete = { text = '_' },
      topdelete = { text = '‾' },
      changedelete = { text = '~' },
      untracked = { text = '┆' },
    },
    signs_staged = {
      add = { text = '┃' },
      change = { text = '┃' },
      delete = { text = '_' },
      topdelete = { text = '‾' },
      changedelete = { text = '~' },
      untracked = { text = '┆' },
    },
    signs_staged_enable = true,
    current_line_blame = not cwd():match('dotfiles'),
    current_line_blame_formatter = '<author>, <author_time:%R> - <summary>',
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns

      local function bmap(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        map(mode, l, r, opts)
      end

      map('n', '<leader>ghu', gs.undo_stage_hunk, { desc = 'Undo Stage Hunk' })
      map('n', '<leader>ghp', gs.preview_hunk_inline, { desc = 'Preview Current Hunk' })
      map('n', '<leader>gtb', gs.toggle_current_line_blame, { desc = 'Toggle Current Line Blame' })
      map('n', '<leader>gtd', gs.toggle_deleted, { desc = 'Show Deleted Lines' })
      map('n', '<leader>gtw', gs.toggle_word_diff, { desc = 'Toggle Word Diff' })
      map('n', '<localleader>gbs', gs.stage_buffer, { desc = 'Stage Entire Buffer' })
      map('n', '<localleader>gbR', gs.reset_buffer, { desc = 'Reset Entire Buffer' })
      map('n', '<localleader>gbl', gs.blame_line, { desc = 'Blame Current Line' })
      map('n', '<leader>lm', function() gs.setqflist('all') end, { desc = 'List Modified in Quickfix' })
      bmap({ 'n', 'v' }, '<localleader>ghs', '<Cmd>Gitsigns stage_hunk<CR>', { desc = 'Stage Hunk' })
      bmap({ 'n', 'v' }, '<localleader>ghr', '<Cmd>Gitsigns reset_hunk<CR>', { desc = 'Reset Hunk' })
      bmap({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { desc = 'Select Hunk' })

      map('n', '[h', function()
        vim.schedule(function() gs.prev_hunk() end)
        return '<Ignore>'
      end, { expr = true, desc = 'Go to previous git hunk' })

      map('n', ']h', function()
        vim.schedule(function() gs.next_hunk() end)
        return '<Ignore>'
      end, { expr = true, desc = 'Go to next git hunk' })
    end,
  },
}
