return {
  style = 'storm',
  transparent = vim.g.neovide == nil,
  terminal_colors = false, -- Configure the colors used when opening a `:terminal` in Neovim
  day_brightness = 0.3, -- Adjusts brightness of the colors of the Day style
  dim_inactive = false,
  lualine_bold = true,

  plugins = {
    all = package.loaded.lazy == nil,
    auto = true,
  },
}
