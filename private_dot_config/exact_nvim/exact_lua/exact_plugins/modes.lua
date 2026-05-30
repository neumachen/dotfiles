return {
  'mvllow/modes.nvim',
  tag = 'v0.2.1',
  event = 'VeryLazy',
  config = function()
    vim.opt.cursorline = true
    require('modes').setup({
      line_opacity = 0.10,
      set_cursor = true,
      set_cursorline = true,
      set_number = true,
      set_signcolumn = true,
    })
  end,
}
