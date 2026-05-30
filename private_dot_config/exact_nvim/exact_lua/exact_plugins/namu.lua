return {
  'bassamsdata/namu.nvim',
  cmd = { 'Namu' },
  keys = {
    { '<localleader>tnb', '<cmd>Namu symbols<cr>', desc = 'Namu buffer symbols' },
    { '<localleader>tnw', '<cmd>Namu workspace<cr>', desc = 'Namu workspace symbols' },
    { '<localleader>tnW', '<cmd>Namu watchtower<cr>', desc = 'Namu watchtower symbols' },
    { '<localleader>tnd', '<cmd>Namu diagnostics<cr>', desc = 'Namu diagnostics symbols' },
    { '<localleader>tnc', '<cmd>Namu ctags<cr>', desc = 'Namu ctags symbols' },
    { '<localleader>tnh', '<cmd>Namu help<cr>', desc = 'Namu help symbols' },
  },
  config = function()
    --- @module 'namu'
    require('namu').setup({
      namu_symbols = {
        enable = true,
        ---@type NamuConfig
        options = {
          AllowKinds = {
            default = {
              'Function',
              'Method',
              'Class',
              'Module',
              'Property',
              'Variable',
              'Constant',
              'Enum',
              'Interface',
              'Field',
              'Struct',
            },
            go = {
              'Function',
              'Method',
              'Struct',
              'Field',
              'Interface',
              'Constant',
              'Variable',
              'Property',
              'TypeParameter',
            },
            lua = { 'Function', 'Method', 'Table', 'Module' },
            python = { 'Function', 'Class', 'Method' },
            yaml = { 'Object', 'Array' },
            json = { 'Module' },
            toml = { 'Object' },
            markdown = { 'String' },
          },
          BlockList = {
            default = {},
            lua = {
              '^vim%.', -- anonymous functions passed to nvim api
              '%.%.%. :', -- vim.iter functions
              ':gsub', -- lua string.gsub
              '^callback$', -- nvim autocmds
              '^filter$',
              '^map$', -- nvim keymaps
            },
            python = { '^__' }, -- ignore __init__ functions
          },
          display = {
            mode = 'icon',
            padding = 2,
          },
          row_position = 'top10',
          preview = {
            highlight_on_move = true,
            highlight_mode = 'always',
          },
          window = {
            auto_size = true,
            min_height = 1,
            min_width = 20,
            max_width = 120,
            max_height = 30,
            padding = 2,
            border = 'rounded',
            title_pos = 'left',
            show_footer = true,
            footer_pos = 'right',
            relative = 'editor',
            style = 'minimal',
            width_ratio = 0.6,
            height_ratio = 0.6,
            title_prefix = '󱠦 ',
          },
          debug = false,
          focus_current_symbol = true,
          auto_select = false,
          initially_hidden = false,
          multiselect = {
            enabled = true,
            indicator = '✓',
            keymaps = {
              toggle = '<Tab>',
              untoggle = '<S-Tab>',
              select_all = '<C-a>',
              clear_all = '<C-l>',
            },
            max_items = nil,
          },
          actions = {
            close_on_yank = false,
            close_on_delete = true,
          },
          movement = {
            next = { '<C-n>', '<DOWN>' },
            previous = { '<C-p>', '<UP>' },
            close = { '<ESC>', '<C-c>', 'q' },
            select = { '<CR>' },
            delete_word = {}, -- it can assign "<C-w>"
            clear_line = {}, -- it can be "<C-u>"
          },
          custom_keymaps = {
            yank = {
              keys = { '<C-y>' },
              desc = 'Yank symbol text',
            },
            delete = {
              keys = { '<C-d>' },
              desc = 'Delete symbol text',
            },
            vertical_split = {
              keys = { '<C-v>' },
              desc = 'Open in vertical split',
            },
            horizontal_split = {
              keys = { '<C-h>' },
              desc = 'Open in horizontal split',
            },
            codecompanion = {
              keys = '<C-o>',
              desc = 'Add symbol to CodeCompanion',
            },
            avante = {
              keys = '<C-t>',
              desc = 'Add symbol to Avante',
            },
          },
          icon = '󱠦',
          kindText = {
            Function = 'function',
            Class = 'class',
            Module = 'module',
            Constructor = 'constructor',
            Interface = 'interface',
            Property = 'property',
            Field = 'field',
            Enum = 'enum',
            Constant = 'constant',
            Variable = 'variable',
          },
          kindIcons = {
            File = '󰈙',
            Module = '󰏗',
            Namespace = '󰌗',
            Package = '󰏖',
            Class = '󰌗',
            Method = '󰆧',
            Property = '󰜢',
            Field = '󰜢',
            Constructor = '󰆧',
            Enum = '󰒻',
            Interface = '󰕘',
            Function = '󰊕',
            Variable = '󰀫',
            Constant = '󰏿',
            String = '󰀬',
            Number = '󰎠',
            Boolean = '󰨙',
            Array = '󰅪',
            Object = '󰅩',
            Key = '󰌋',
            Null = '󰟢',
            EnumMember = '󰒻',
            Struct = '󰌗',
            Event = '󰉁',
            Operator = '󰆕',
            TypeParameter = '󰊄',
          },
          highlight = 'NamuPreview',
          highlights = {
            parent = 'NamuParent',
            nested = 'NamuNested',
            style = 'NamuStyle',
          },
          kinds = {
            prefix_kind_colors = true,
            enable_highlights = true,
            highlights = {
              PrefixSymbol = 'NamuPrefixSymbol',
              Function = 'NamuSymbolFunction',
              Method = 'NamuSymbolMethod',
              Class = 'NamuSymbolClass',
              Interface = 'NamuSymbolInterface',
              Variable = 'NamuSymbolVariable',
              Constant = 'NamuSymbolConstant',
              Property = 'NamuSymbolProperty',
              Field = 'NamuSymbolField',
              Enum = 'NamuSymbolEnum',
              Module = 'NamuSymbolModule',
            },
          },
        },
      },
    })

    -- NOTE: keymaps moved to top-level `keys = { ... }` so lazy.nvim can
    -- trigger plugin load on first use (was eager when defined here).
  end,
}
