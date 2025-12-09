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

local function to_hex(color)
  if type(color) ~= 'number' then return nil end
  return string.format('#%06x', color)
end

local function get_highlight_attr(group, attr)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
  if not ok or not hl then return nil end
  return hl[attr]
end

local function get_highlight_hex(group, attr)
  local value = get_highlight_attr(group, attr)
  if not value then return nil end
  return to_hex(value)
end


local function apply_background(background_hex)
  if not background_hex then return end

  for _, group in ipairs(BACKGROUND_GROUPS) do
    local opts = { bg = background_hex }
    local fg_hex = get_highlight_hex(group, 'fg')
    if fg_hex then opts.fg = fg_hex end
    vim.api.nvim_set_hl(0, group, opts)
  end
end

local M = {}

M.opts = {}

function M.apply_overrides()
  if vim.o.background ~= 'light' then apply_background(BACKGROUND_DARK) end
end

return M
