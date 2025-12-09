local BACKGROUND_DARK = '#2C3441'
local BACKGROUND_GROUPS = {
  'Normal',
  'NormalNC',
  'NormalSB',
  'NormalFloat',
  'SignColumn',
  'FoldColumn',
  'StatusLine',
}

local function is_light_background() return vim.o.background == 'light' end

local function set_background_colors(highlights, background)
  if not background then return end
  for _, group in ipairs(BACKGROUND_GROUPS) do
    highlights[group] = highlights[group] or {}
    highlights[group].bg = background
  end
end


return {
  style = 'storm',
  light_style = 'day',
  transparent = false,
  terminal_colors = true, -- Configure the colors used when opening a `:terminal` in Neovim
  styles = {
    -- Style to be applied to different syntax groups
    -- Value is any valid attr-list value for `:help nvim_set_hl`
    comments = { italic = true },
    keywords = { italic = true },
    functions = {},
    variables = {},
    -- Background styles. Can be "dark", "transparent" or "normal"
    sidebars = 'dark', -- style for sidebars, see below
    floats = 'dark', -- style for floating windows
  },
  day_brightness = 0.3, -- Adjusts brightness of the colors of the Day style
  dim_inactive = false,
  lualine_bold = true,

  on_colors = function(colors)
    if is_light_background() then return end

    colors.bg = BACKGROUND_DARK
    colors.bg_dark = BACKGROUND_DARK
    colors.bg_float = BACKGROUND_DARK
    colors.bg_highlight = BACKGROUND_DARK
    colors.bg_sidebar = BACKGROUND_DARK
    colors.bg_statusline = BACKGROUND_DARK
  end,

  on_highlights = function(highlights, colors)
    if not is_light_background() then
      set_background_colors(highlights, BACKGROUND_DARK)
    end
  end,

  cache = true,

  plugins = {
    all = package.loaded.lazy == nil,
    auto = true,
  },
}
