return {
  style = 'storm',
  light_style = 'day',
  transparent = true,
  terminal_colors = false, -- Configure the colors used when opening a `:terminal` in Neovim
  -- styles = {
  --   -- Style to be applied to different syntax groups
  --   -- Value is any valid attr-list value for `:help nvim_set_hl`
  --   comments = { italic = true },
  --   keywords = { italic = true },
  --   functions = {},
  --   variables = {},
  --   -- Background styles. Can be "dark", "transparent" or "normal"
  --   sidebars = 'dark', -- style for sidebars, see below
  --   floats = 'dark', -- style for floating windows
  -- },
  day_brightness = 0.3, -- Adjusts brightness of the colors of the Day style
  dim_inactive = false,
  lualine_bold = true,

  plugins = {
    all = package.loaded.lazy == nil,
    auto = true,
  },
}
