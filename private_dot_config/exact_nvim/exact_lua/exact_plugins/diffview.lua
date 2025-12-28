---@module "lazy"
---@type LazySpec
return {
  'sindrets/diffview.nvim',
  key = {
    {
      '<localleader>gd',
      '<Cmd>DiffviewOpen<CR>',
      desc = 'diffview: open',
      mode = 'n',
    },
    {
      'gh',
      [[:'<'>DiffviewFileHistory<CR>]],
      desc = 'diffview: file history',
      mode = 'v',
    },
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
    view = {
      default = {
        winbar_info = true,
      },
      merge_tool = {
        winbar_info = true,
      },
      file_history = {
        winbar_info = true,
      },
    },
    hooks = {
      diff_buf_read = function()
        local opt = vim.opt_local
        opt.wrap, opt.list, opt.relativenumber = false, false, false
        opt.colorcolumn = ''
      end,
      diff_buf_win_enter = function(bufnr, winid, ctx)
        -- Add custom winbar with branch and commit info
        if ctx.layout_name:match('diff') then
          local function get_git_info()
            local branch =
              vim.fn.system('git branch --show-current'):gsub('\n', '')
            local commit =
              vim.fn.system('git rev-parse --short HEAD'):gsub('\n', '')
            return string.format('Branch: %s | Commit: %s', branch, commit)
          end

          local function get_ref_info(symbol)
            if symbol and symbol.commit then
              local short_commit = symbol.commit:sub(1, 7)
              local ref_name = symbol.name or 'unknown'
              return string.format('%s (%s)', ref_name, short_commit)
            end
            return get_git_info()
          end

          vim.api.nvim_set_option_value(
            'winbar',
            get_ref_info(ctx.symbol),
            { win = winid }
          )
        end
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
