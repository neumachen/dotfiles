-- after/ftplugin/slim.lua

-- Helper to behave like `highlight default link`
local function default_link(from, to)
  local ok, existing =
    pcall(vim.api.nvim_get_hl, 0, { name = from, link = false })
  if not ok or not existing or next(existing) == nil then
    vim.api.nvim_set_hl(0, from, { link = to })
  end
end

-- These names match the captures in queries/slim/highlights.scm
local links = {
  ['@tag.slim'] = 'Tag',
  ['@tag.name.slim'] = 'Tag',
  ['@tag.attribute.slim'] = 'Type',

  ['@attribute.slim'] = 'Identifier',
  ['@string.slim'] = 'String',
  ['@comment.slim'] = 'Comment',
  ['@operator.slim'] = 'Operator',
}

for from, to in pairs(links) do
  default_link(from, to)
end
