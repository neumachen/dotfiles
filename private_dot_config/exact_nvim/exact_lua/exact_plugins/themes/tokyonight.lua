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
  end,
}
