return {
  'KieranCanter/candela.nvim',
  keys = {
    { '<localleader>cc', '<Plug>CandelaUi', desc = 'Candela UI' },
    { '<localleader>cr', '<Plug>CandelaRefresh', desc = 'Candela refresh' },
    { '<localleader>cx', '<Plug>CandelaClear', desc = 'Candela clear' },
    { '<localleader>cl', '<Plug>CandelaLightbox', desc = 'Candela lightbox' },
  },
  config = function()
    require('candela').setup({
      window = {
        width = 0.5,
        min_height = 5,
        max_height = 30,
        margin = 16,
        min_count_width = 4,
        toggle_width = 6,
        prompt_offset = 'overlap',
      },
      engine = {
        command = nil,
        args = {},
      },
      matching = {
        auto_refresh = false,
        delete_confirmation = true,
        clear_confirmation = true,
        case = 'system',
        hl_eol = false,
      },
      lightbox = {
        view = 'system-vsplit',
        fold_style = 'nvim',
        fillchar = '-',
        custom_foldtext = nil,
      },
      icons = vim.g.have_nerd_font
          and {
            candela = '\u{f05e2}', -- 󰗢
            color = '\u{e22b}', -- 
            regex = '\u{f069}', -- 
            highlight = {
              header = '\u{ea61}', -- 
              toggle_on = '\u{f1a25}', -- 󱨥
              toggle_off = '\u{f1a26}', -- 󱨦
            },
            lightbox = {
              header = '\u{e68f}', -- 
              toggle_on = '\u{f1a25}', -- 󱨥
              toggle_off = '\u{f1a26}', -- 󱨦
            },
          }
        or {
          candela = '\u{1F56F}', -- 🕯
          color = '\u{1F3A8}', -- 🎨
          regex = '\u{2728}', -- ✨
          highlight = {
            header = '\u{1F4A1}', -- 💡
            toggle_on = '\u{25C9}', -- ◉
            toggle_off = '\u{25CB}', -- ○
          },
          lightbox = {
            header = '\u{1F50D}', -- 🔍
            toggle_on = '\u{25C9}', -- ◉
            toggle_off = '\u{25CB}', -- ○
          },
        },
      palette = {
        use = 'replace',
        cycle = 'constant',
        colors = {
          dark = {
            '#9D4564', -- DARK MAUVE
            '#A1464C', -- LIGHT MAROON
            '#9E4D21', -- SIENNA
            '#935800', -- MUD
            '#7F6400', -- MUSTARD
            '#6C6C00', -- MOSS
            '#4C7522', -- LEAF GREEN
            '#257A3F', -- JEWEL GREEN
            '#007C6A', -- AQUAMARINE
            '#007690', -- OCEAN
            '#3368AB', -- MUTED BLUE
            '#565FAC', -- DUSKY BLUE
            '#7156A3', -- DARK LAVENDER
            '#805098', -- EGGPLANT
            '#94487C', -- ROUGE
          },
          light = {
            '#F08FAE', -- PINK SHERBET
            '#F49093', -- SEA PINK
            '#F0986D', -- TANGERINE
            '#E2A25D', -- DESERT
            '#CBAE5E', -- GOLD
            '#B6B75F', -- OLIVE
            '#94C16F', -- PISTACHIO
            '#75C787', -- MANTIS
            '#65C5B1', -- NEPTUNE
            '#64BFDB', -- BLUISH CYAN
            '#7CB4FD', -- CRYSTAL BLUE
            '#9DAAFE', -- PERIWINKLE
            '#BBA0F3', -- LILAC
            '#CD9AE7', -- BABY PURPLE
            '#E592C8', -- LIGHT ORCHID
          },
        },
        swatches = {
          dark = {
            GRAY = '#676767',
            RED = '#A1454F',
            BLUE = '#016DA6',
            YELLOW = '#7B6600',
            GREEN = '#2A793C',
            ORANGE = '#9A510B',
            PURPLE = '#7055A3',
          },
          light = {
            GRAY = '#B1B1B1',
            RED = '#F59282',
            BLUE = '#3BC3E5',
            YELLOW = '#C6B14D',
            GREEN = '#82C57C',
            ORANGE = '#EC9C60',
            PURPLE = '#AAA5FB',
          },
        },
      },
      syntax_highlighting = {
        enabled = true,
        file_types = { '.log', 'text' },
      },
    })
  end,
}
