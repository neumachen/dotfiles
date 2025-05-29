local cwd = vim.fn.getcwd
local map = map or vim.keymap.set

return {
  'lewis6991/gitsigns.nvim',
  event = { 'BufReadPre', 'BufNewFile' },
  opts = {
    current_line_blame = not cwd():match('dotfiles'),
    current_line_blame_formatter = ' <author>, <author_time> · <summary>',
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns

      local function bmap(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        map(mode, l, r, opts)
      end

      map('n', '<leader>hu', gs.undo_stage_hunk, { desc = 'undo stage' })
      map('n', '<leader>hp', gs.preview_hunk_inline, { desc = 'preview current hunk' })
      map('n', '<leader>hb', gs.toggle_current_line_blame, { desc = 'toggle current line blame' })
      map('n', '<leader>hd', gs.toggle_deleted, { desc = 'show deleted lines' })
      map('n', '<leader>hw', gs.toggle_word_diff, { desc = 'toggle word diff' })
      map('n', '<localleader>gw', gs.stage_buffer, { desc = 'stage entire buffer' })
      map('n', '<localleader>gre', gs.reset_buffer, { desc = 'reset entire buffer' })
      map('n', '<localleader>gbl', gs.blame_line, { desc = 'blame current line' })
      map('n', '<leader>lm', function() gs.setqflist('all') end, { desc = 'list modified in quickfix' })
      bmap({ 'n', 'v' }, '<leader>hs', '<Cmd>Gitsigns stage_hunk<CR>', { desc = 'stage hunk' })
      bmap({ 'n', 'v' }, '<leader>hr', '<Cmd>Gitsigns reset_hunk<CR>', { desc = 'reset hunk' })
      bmap({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { desc = 'select hunk' })

      map('n', '[h', function()
        vim.schedule(function() gs.next_hunk() end)
        return '<Ignore>'
      end, { expr = true, desc = 'go to next git hunk' })

      map('n', ']h', function()
        vim.schedule(function() gs.prev_hunk() end)
        return '<Ignore>'
      end, { expr = true, desc = 'go to previous git hunk' })
    end,
  },
}
