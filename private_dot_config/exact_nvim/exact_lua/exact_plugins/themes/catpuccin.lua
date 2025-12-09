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

local function extend_with_background(highlights, background)
  if not background then return highlights end

  for _, group in ipairs(BACKGROUND_GROUPS) do
    local current = highlights[group] or {}
    current.bg = background
    highlights[group] = current
  end

  return highlights
end

local function is_dark_background()
  return vim.o.background ~= 'light'
end


local function build_color_overrides()
  local overrides = {}
  for _, flavour in ipairs({ 'mocha', 'macchiato', 'frappe' }) do
    overrides[flavour] = {
      base = BACKGROUND_DARK,
      mantle = BACKGROUND_DARK,
      crust = BACKGROUND_DARK,
    }
  end
  return overrides
end

return {
  flavour = 'auto', -- latte, frappe, macchiato, mocha
  background = { -- :h background
    light = 'latte',
    dark = 'mocha',
  },
  transparent_background = false, -- disables setting the background color.
  float = {
    transparent = false, -- enable transparent floating windows
    solid = false, -- use solid styling for floating windows, see |winborder|
  },
  show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
  term_colors = true, -- sets terminal colors (e.g. `g:terminal_color_0`)
  dim_inactive = {
    enabled = false, -- dims the background color of inactive window
    shade = 'dark',
    percentage = 0.15, -- percentage of the shade to apply to the inactive window
  },
  no_italic = false, -- Force no italic
  no_bold = false, -- Force no bold
  no_underline = false, -- Force no underline
  styles = { -- Handles the styles of general hi groups (see `:h highlight-args`):
    comments = { 'italic' }, -- Change the style of comments
    conditionals = { 'italic' },
    loops = {},
    functions = {},
    keywords = {},
    strings = {},
    variables = {},
    numbers = {},
    booleans = {},
    properties = {},
    types = {},
    operators = {},
    -- miscs = {}, -- Uncomment to turn off hard-coded styles
  },
  lsp_styles = { -- Handles the style of specific lsp hl groups (see `:h lsp-highlight`).
    virtual_text = {
      errors = { 'italic' },
      hints = { 'italic' },
      warnings = { 'italic' },
      information = { 'italic' },
      ok = { 'italic' },
    },
    underlines = {
      errors = { 'underline' },
      hints = { 'underline' },
      warnings = { 'underline' },
      information = { 'underline' },
      ok = { 'underline' },
    },
    inlay_hints = {
      background = true,
    },
  },
  color_overrides = build_color_overrides(),
  custom_highlights = function(colors)
    local background = is_dark_background() and BACKGROUND_DARK or nil
    return extend_with_background({}, background)
  end,
  default_integrations = true,
  auto_integrations = false,
  integrations = {
    cmp = true,
    gitsigns = true,
    nvimtree = true,
    notify = false,
    mini = {
      enabled = true,
      indentscope_color = '',
    },
  },
}
