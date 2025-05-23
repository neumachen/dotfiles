local cwd = vim.fn.getcwd
local highlight = as.highlight
local border = as.ui.current.border
local icons = as.ui.icons.separators
local map = map or vim.keymap.set

return {
  {
    'akinsho/git-conflict.nvim',
    event = 'VeryLazy',
  },
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'sindrets/diffview.nvim',
    },
    config = function()
      require('neogit').setup({
        disable_signs = false,
        disable_hint = true,
        disable_commit_confirmation = true,
        disable_builtin_notifications = true,
        disable_insert_on_commit = false,
        signs = {
          section = { '', '󰘕' }, -- "󰁙", "󰁊"
          item = { '▸', '▾' },
          hunk = { '󰐕', '󰍴' },
        },
        integrations = {
          telescope = true,
          diffview = true,
        },
      })

      local neogit = require('neogit')
      map('n', '<localleader>gs', function() neogit.open() end, {
        desc = 'open status buffer',
      })
      map('n', '<localleader>gc', function() neogit.open({ 'commit' }) end, {
        desc = 'open status buffer',
      })
      map('n', '<localleader>gpl', function() neogit.open({ 'pull' }) end, {
        desc = 'open pull popup',
      })
      map('n', '<localleader>gps', function() neogit.open({ 'push' }) end, {
        desc = 'open push popup',
      })
    end,
  },
  {
    'sindrets/diffview.nvim',
    key = {
      { '<localleader>gd', '<Cmd>DiffviewOpen<CR>', desc = 'diffview: open', mode = 'n' },
      { 'gh', [[:'<'>DiffviewFileHistory<CR>]], desc = 'diffview: file history', mode = 'v' },
      {
        '<localleader>gh',
        '<Cmd>DiffviewFileHistory<CR>',
        desc = 'diffview: file history',
        mode = 'n',
      },
    },
    opts = {
      default_args = { DiffviewFileHistory = { '%' } },
      enhanced_diff_hl = true,
      hooks = {
        diff_buf_read = function()
          local opt = vim.opt_local
          opt.wrap, opt.list, opt.relativenumber = false, false, false
          opt.colorcolumn = ''
        end,
      },
      keymaps = {
        view = { q = '<Cmd>DiffviewClose<CR>' },
        file_panel = { q = '<Cmd>DiffviewClose<CR>' },
        file_history_panel = { q = '<Cmd>DiffviewClose<CR>' },
      },
    },
    config = function(_, opts)
      highlight.plugin('diffview', {
        { DiffAddedChar = { bg = 'NONE', fg = { from = 'diffAdded', attr = 'bg', alter = 0.3 } } },
        {
          DiffChangedChar = { bg = 'NONE', fg = { from = 'diffChanged', attr = 'bg', alter = 0.3 } },
        },
        { DiffviewStatusAdded = { link = 'DiffAddedChar' } },
        { DiffviewStatusModified = { link = 'DiffChangedChar' } },
        { DiffviewStatusRenamed = { link = 'DiffChangedChar' } },
        { DiffviewStatusUnmerged = { link = 'DiffChangedChar' } },
        { DiffviewStatusUntracked = { link = 'DiffAddedChar' } },
      })
      require('diffview').setup(opts)
    end,
  },
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      signs = {
        add = { text = icons.right_block },
        change = { text = icons.right_block },
        delete = { text = icons.right_block },
        topdelete = { text = icons.right_block },
        changedelete = { text = icons.right_block },
        untracked = { text = icons.light_shade_block },
      },
      current_line_blame = not cwd():match('dotfiles'),
      current_line_blame_formatter = ' <author>, <author_time> · <summary>',
      preview_config = { border = border },
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
  },
}
