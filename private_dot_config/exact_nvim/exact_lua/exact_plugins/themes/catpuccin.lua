return {
  flavour = 'mocha', -- latte, frappe, macchiato, mocha
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
  -- Window dividers: catppuccin's default WinSeparator links to a
  -- surface tone (~#45475a on mocha) which is nearly invisible against
  -- the base background. Promote to overlay1 so split seams and
  -- sidebar edges (yazi, snacks explorer, aerial, trouble, neo-tree)
  -- are obvious in every dock direction. Mirrors the tokyonight
  -- override in themes/tokyonight.lua; both run on every (re)apply
  -- so no ColorScheme autocmd is needed.
  custom_highlights = function(C)
    local sep = { fg = C.overlay1, bg = C.base }
    return {
      WinSeparator = sep,
      VertSplit = sep,
      NeoTreeWinSeparator = sep,
      YaziWinSeparator = sep,
      SnacksWinSeparator = sep,
      FloatBorder = { fg = C.overlay1, bg = C.base },
      NormalFloat = { fg = C.text, bg = C.base },
      StatusLine = { fg = C.text, bg = C.mantle },
      StatusLineNC = { fg = C.overlay1, bg = C.mantle },
      WinBar = { fg = C.text, bg = C.base },
      WinBarNC = { fg = C.overlay1, bg = C.base },
    }
  end,
}
