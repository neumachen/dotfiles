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
  color_overrides = {}, -- Additional color overrides
}
