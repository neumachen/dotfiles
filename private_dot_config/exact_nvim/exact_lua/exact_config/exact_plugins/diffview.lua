local highlight = config.highlight

return {
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
  config = function(_, opts) require('diffview').setup(opts) end,
}
