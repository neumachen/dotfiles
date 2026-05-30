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
    -- Use the todo-comment blue for relative/non-current line numbers,
    -- matching @comment.todo = { fg = "#7AA2F7" }
    hl.LineNr = { fg = c.blue }
  end,
}
