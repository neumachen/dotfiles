return {
  style = 'storm',
  transparent = false,
  terminal_colors = true,
  lualine_bold = true,
  plugins = {
    all = package.loaded.lazy == nil,
    auto = true,
  },
  on_highlights = function(hl, c)
    -- Match ColorColumn to CursorLine so the column marker blends naturally
    hl.ColorColumn = { bg = c.bg_highlight }
    -- Use the todo-comment blue for all non-current line numbers,
    -- matching @comment.todo = { fg = "#7AA2F7" } (c.blue = #7AA2F7).
    -- LineNrAbove/LineNrBelow control relative numbers above/below the
    -- cursor; LineNr is the fallback for absolute mode and must also be
    -- set so both number modes stay consistent.
    hl.LineNr = { fg = c.blue }
    hl.LineNrAbove = { fg = c.blue }
    hl.LineNrBelow = { fg = c.blue }

    -- Window dividers: tokyonight's default points WinSeparator at
    -- c.border (~#1b1d2b), which is nearly indistinguishable from
    -- c.bg (#24283b). Bump to c.fg_dark so split seams and sidebar
    -- edges (yazi, snacks explorer, aerial, trouble, neo-tree) are
    -- obvious in every dock direction. bg is set explicitly so
    -- transparent terminals do not eat the line.
    local sep = { fg = c.fg_dark, bg = c.bg }
    hl.WinSeparator = sep
    hl.VertSplit = sep
    hl.NeoTreeWinSeparator = sep
    hl.YaziWinSeparator = sep
    hl.SnacksWinSeparator = sep

    -- Float borders (yazi floating mode, aerial nav, noice popups,
    -- snacks pickers) — visible against transparent terminals.
    hl.FloatBorder = { fg = c.fg_dark, bg = c.bg_float }
    hl.NormalFloat = { fg = c.fg, bg = c.bg_float }

    -- Statusline band acts as a horizontal-split divider once
    -- lualine drops laststatus from 3 to 2 post-VeryLazy.
    hl.StatusLine = { fg = c.fg, bg = c.bg_statusline }
    hl.StatusLineNC = { fg = c.fg_dark, bg = c.bg_statusline }

    -- Winbar band acts as a top-edge divider when shown. Keep the
    -- inactive variant readable so it functions as a separator.
    hl.WinBar = { fg = c.fg, bg = c.bg }
    hl.WinBarNC = { fg = c.fg_dark, bg = c.bg }
  end,
}
