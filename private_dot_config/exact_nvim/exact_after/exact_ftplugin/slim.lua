-- after/ftplugin/slim.lua

-- Helper to set a default link only if nothing else has claimed it
local function default_link(from, to)
  -- Try to get existing highlight; if empty or missing, set the link
  local ok, existing = pcall(vim.api.nvim_get_hl, 0, { name = from, link = false })
  if not ok or not existing or next(existing) == nil then vim.api.nvim_set_hl(0, from, { link = to }) end
end

-- Map Treesitter captures to standard highlight groups.
-- Colorscheme (e.g. tokyonight-storm) defines the actual colors for Tag, String, etc.
local links = {
  ['@tag.slim'] = 'Tag',
  ['@tag.delimiter.slim'] = 'Delimiter',
  ['@attribute.slim'] = 'Identifier',
  ['@string.slim'] = 'String',
  ['@comment.slim'] = 'Comment',
  ['@operator.slim'] = 'Operator',
  ['@text.slim'] = 'Normal',

  -- Embedded Ruby inside Slim
  ['@keyword.ruby'] = 'Keyword',
  ['@variable.ruby'] = 'Identifier',
}

for from, to in pairs(links) do
  default_link(from, to)
end
