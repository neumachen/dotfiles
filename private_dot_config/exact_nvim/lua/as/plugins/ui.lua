---@diagnostic disable: missing-fields
local api, fn = vim.api, vim.fn
local highlight, ui, falsy, augroup = as.highlight, as.ui, as.falsy, as.augroup
local icons, border = ui.icons.lsp, ui.current.border

local lspkind = require('lspkind')

return {
  {
    'folke/zen-mode.nvim',
    cmd = 'ZenMode',
    opts = {
      plugins = {
        wezterm = { enabled = true, font = '+4' },
        kitty = { enabled = true, font = '+2' },
        tmux = { enabled = true },
      },
    },
  },
  {
    'Bekaboo/dropbar.nvim',
    event = 'VeryLazy',
    keys = { { '<leader>wp', function() require('dropbar.api').pick() end, desc = 'winbar: pick' } },
    init = function()
      highlight.plugin('DropBar', {
        { DropBarIconUISeparator = { link = 'Delimiter' } },
        { DropBarMenuNormalFloat = { inherit = 'Pmenu' } },
      })
    end,
    bar = {
      general = {
        update_interval = 100,
        enable = function(buf, win)
          local b, w = vim.bo[buf], vim.wo[win]
          local decor = ui.decorations.get({ ft = b.ft, bt = b.bt, setting = 'winbar' })
          return decor.ft ~= false
            and decor.bt ~= false
            and b.bt == ''
            and not w.diff
            and not api.nvim_win_get_config(win).zindex
            and api.nvim_buf_get_name(buf) ~= ''
        end,
      },
      icons = {
        ui = { bar = { separator = ' ' .. ui.icons.misc.arrow_right .. ' ' } },
        kinds = {
          symbols = vim.tbl_map(function(value) return value .. ' ' end, lspkind.symbol_map),
        },
      },
      menu = {
        win_configs = {
          border = 'shadow',
          col = function(menu) return menu.prev_menu and menu.prev_menu._win_configs.width + 1 or 0 end,
        },
      },
    },
  },
  {
    'lukas-reineke/virt-column.nvim',
    event = 'VimEnter',
    opts = { char = '▕' },
    init = function()
      augroup('VirtCol', {
        event = { 'VimEnter', 'BufEnter', 'WinEnter' },
        command = function(args)
          ui.decorations.set_colorcolumn(
            args.buf,
            function(virtcolumn) require('virt-column').setup_buffer({ virtcolumn = virtcolumn }) end
          )
        end,
      })
    end,
  },
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    event = 'UIEnter',
    opts = {
      exclude = {
        -- stylua: ignore
        filetypes = {
          'dbout', 'neo-tree-popup', 'log', 'gitcommit',
          'txt', 'help', 'NvimTree', 'git',
          'undotree', 'markdown', 'oil',
        },
      },
      indent = {
        char = '│', -- ▏┆ ┊ 
        tab_char = '│',
      },
      scope = {
        char = '▎',
        highlight = {
          'RainbowDelimiterRed',
          'RainbowDelimiterYellow',
          'RainbowDelimiterBlue',
          'RainbowDelimiterOrange',
          'RainbowDelimiterGreen',
          'RainbowDelimiterViolet',
          'RainbowDelimiterCyan',
        },
      },
    },
    config = function(_, opts)
      require('ibl').setup(opts)
      local hooks = require('ibl.hooks')
      hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
      hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)
    end,
  },
  {
    'stevearc/dressing.nvim',
    init = function()
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.select = function(...)
        require('lazy').load({ plugins = { 'dressing.nvim' } })
        return vim.ui.select(...)
      end
    end,
    opts = {
      input = { enabled = false },
      select = {
        backend = { 'fzf_lua', 'builtin' },
        builtin = {
          border = border,
          min_height = 10,
          win_options = { winblend = 10 },
          mappings = { n = { ['q'] = 'Close' } },
        },
        get_config = function(opts)
          opts.prompt = opts.prompt and opts.prompt:gsub(':', '')
          if opts.kind == 'codeaction' then
            return {
              backend = 'fzf_lua',
              fzf_lua = as.fzf.cursor_dropdown({
                winopts = { title = opts.prompt },
              }),
            }
          end
          return {
            backend = 'fzf_lua',
            fzf_lua = as.fzf.dropdown({
              winopts = { title = opts.prompt, height = 0.33, row = 0.5 },
            }),
          }
        end,
        nui = {
          min_height = 10,
          win_options = {
            winhighlight = table.concat({
              'Normal:Italic',
              'FloatBorder:PickerBorder',
              'FloatTitle:Title',
              'CursorLine:Visual',
            }, ','),
          },
        },
      },
    },
  },
  {
    'rcarriga/nvim-notify',
    config = function()
      local notify = require('notify')

      notify.setup({
        timeout = 5000,
        fps = 30,
        stages = 'fade_in_slide_out',
        top_down = true,
        background_colour = 'NotifyBackground',
      })
      map('n', '<leader>nd', function() notify.dismiss({ silent = true, pending = true }) end, {
        desc = 'dismiss notifications',
      })
    end,
  },
  {
    'akinsho/bufferline.nvim',
    event = 'UIEnter',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local bufferline = require('bufferline')
      bufferline.setup({
        options = {
          debug = { logging = true },
          style_preset = { bufferline.style_preset.minimal },
          mode = 'buffers',
          sort_by = 'insert_after_current',
          move_wraps_at_ends = true,
          right_mouse_command = 'vert sbuffer %d',
          show_close_icon = false,
          show_buffer_close_icons = true,
          indicator = { style = 'underline' },
          diagnostics = 'nvim_lsp',
          diagnostics_indicator = function(count, level)
            level = level:match('warn') and 'warn' or level
            return (icons[level] or '?') .. ' ' .. count
          end,
          diagnostics_update_in_insert = false,
          hover = { enabled = true, reveal = { 'close' } },
          offsets = {
            {
              text = 'EXPLORER',
              filetype = 'neo-tree',
              highlight = 'PanelHeading',
              text_align = 'left',
              separator = true,
            },
            {
              text = 'UNDOTREE',
              filetype = 'undotree',
              highlight = 'PanelHeading',
              separator = true,
            },
            {
              text = '󰆼 DATABASE VIEWER',
              filetype = 'dbui',
              highlight = 'PanelHeading',
              separator = true,
            },
            {
              text = ' DIFF VIEW',
              filetype = 'DiffviewFiles',
              highlight = 'PanelHeading',
              separator = true,
            },
          },
          groups = {
            options = { toggle_hidden_on_enter = true },
            items = {
              bufferline.groups.builtin.pinned:with({ icon = '' }),
              bufferline.groups.builtin.ungrouped,
              {
                name = 'Dependencies',
                icon = '',
                highlight = { fg = '#ECBE7B' },
                matcher = function(buf) return vim.startswith(buf.path, vim.env.VIMRUNTIME) end,
              },
              {
                name = 'Terraform',
                matcher = function(buf) return buf.name:match('%.tf') ~= nil end,
              },
              {
                name = 'Kubernetes',
                matcher = function(buf) return buf.name:match('kubernetes') and buf.name:match('%.yaml') end,
              },
              {
                name = 'SQL',
                matcher = function(buf) return buf.name:match('%.sql$') end,
              },
              {
                name = 'tests',
                icon = '',
                matcher = function(buf)
                  local name = buf.name
                  return name:match('[_%.]spec') or name:match('[_%.]test')
                end,
              },
              {
                name = 'docs',
                icon = '',
                matcher = function(buf)
                  if vim.bo[buf.id].filetype == 'man' or buf.path:match('man://') then return true end
                  for _, ext in ipairs({ 'md', 'txt', 'wiki' }) do
                    if ext == fn.fnamemodify(buf.path, ':e') then return true end
                  end
                end,
              },
            },
          },
        },
      })

      map('n', '[b', '<Cmd>BufferLineMoveNext<CR>', { desc = 'bufferline: move next' })
      map('n', ']b', '<Cmd>BufferLineMovePrev<CR>', { desc = 'bufferline: move prev' })
      map('n', 'gbb', '<Cmd>BufferLinePick<CR>', { desc = 'bufferline: pick buffer' })
      map('n', 'gbd', '<Cmd>BufferLinePickClose<CR>', { desc = 'bufferline: delete buffer' })
      map('n', '<S-tab>', '<Cmd>BufferLineCyclePrev<CR>', { desc = 'bufferline: prev' })
      map('n', '<leader><tab>', '<Cmd>BufferLineCycleNext<CR>', { desc = 'bufferline: next' })
    end,
  },
  {
    'folke/trouble.nvim',
    lazy = false,
    opts = {}, -- for default options, refer to the configuration section for custom setup.
    cmd = 'Trouble',
    keys = {
      {
        '<leader>xx',
        '<cmd>Trouble diagnostics toggle<cr>',
        desc = 'Diagnostics (Trouble)',
      },
      {
        '<leader>xX',
        '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
        desc = 'Buffer Diagnostics (Trouble)',
      },
      {
        '<leader>cs',
        '<cmd>Trouble symbols toggle focus=false<cr>',
        desc = 'Symbols (Trouble)',
      },
      {
        '<leader>cl',
        '<cmd>Trouble lsp toggle focus=false win.position=right<cr>',
        desc = 'LSP Definitions / references / ... (Trouble)',
      },
      {
        '<leader>xL',
        '<cmd>Trouble loclist toggle<cr>',
        desc = 'Location List (Trouble)',
      },
      {
        '<leader>xQ',
        '<cmd>Trouble qflist toggle<cr>',
        desc = 'Quickfix List (Trouble)',
      },
    },
  },
}
