local function resolve_theme()
  if type(vim) == 'table' and vim.o then
    local background = vim.o.background
    if background == 'light' or background == 'dark' then return background end
  end
  return 'dark'
end

local styles_by_theme = {
  dark = {
    comments = 'italic',
    keywords = 'bold',
    diagnostics = 'underline',
  },
  light = {
    comments = 'italic',
    keywords = 'bold',
    functions = 'italic',
    diagnostics = 'underline',
  },
}

local background_by_theme = {
  dark = '#2C3441',
}

local function build_custom_colors()
  local custom_colors = {}
  for theme_name, background in pairs(background_by_theme) do
    custom_colors[theme_name] = {
      bg = background,
      float = background,
      menu = background,
    }
  end
  return custom_colors
end

local function build_custom_highlights()
  local highlights = {
    all = {},
  }

  if background_by_theme.dark then
    highlights.dark = {
      Normal = { bg = background_by_theme.dark },
      NormalNC = { bg = background_by_theme.dark },
      NormalSB = { bg = background_by_theme.dark },
      NormalFloat = { bg = background_by_theme.dark },
      SignColumn = { bg = background_by_theme.dark },
      FoldColumn = { bg = background_by_theme.dark },
      StatusLine = { bg = background_by_theme.dark },
    }
  end

  return highlights
end

local theme = resolve_theme()

return {
  theme = theme,
  borders = true, -- Split window borders
  fade_nc = false, -- Fade non-current windows, making them more distinguishable
  -- Style that is applied to various groups
  styles = styles_by_theme[theme] or styles_by_theme.dark,
  disable = {
    background = false, -- Disable setting the background color
    float_background = false, -- Disable setting the background color for floating windows
    cursorline = false, -- Disable the cursorline
    eob_lines = true, -- Hide the end-of-buffer lines
  },
  -- Inverse highlight for different groups
  inverse = {
    match_paren = false,
  },
  -- custom_highlights = build_custom_highlights(),
  -- custom_colors = build_custom_colors(),
  color_overrides = {}, -- Additional color overrides
}
