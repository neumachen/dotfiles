-- Ensure tabs are converted to spaces in markdown files
vim.opt_local.expandtab = true

-- ------------------------------------------------------------------------- {{{
-- Markdown list mappings (buffer-local).
--
-- These operate on the current visual selection, transforming each line and
-- then reselecting the same lines linewise so the global `>` / `<` mappings can
-- immediately nest/outdent the freshly created list.

-- Split a line into leading indentation, an optional existing list marker
-- (unordered `-`/`+`/`*` or ordered `<digits>.`), and the remaining content.
-- Detecting the marker lets us swap markers instead of stacking them.
local function split_line(line)
  local indent, marker, content = line:match('^(%s*)([-+*]%s+)(.*)$')
  if not indent then
    indent, marker, content = line:match('^(%s*)(%d+%.%s+)(.*)$')
  end
  if not indent then
    indent, content = line:match('^(%s*)(.*)$')
    marker = nil
  end
  return indent, marker, content
end

-- Convert a line to an unordered list item, preserving indentation and
-- replacing any existing marker. Blank lines are left untouched.
local function to_bullet(line)
  if line:match('^%s*$') then return line end
  local indent, _, content = split_line(line)
  return indent .. '- ' .. content
end

-- Convert a line to an ordered list item using `1. ` (repeated `1.` is valid
-- Markdown), preserving indentation and replacing any existing marker.
local function to_ordered(line)
  if line:match('^%s*$') then return line end
  local indent, _, content = split_line(line)
  return indent .. '1. ' .. content
end

-- Remove one unordered or ordered list marker, preserving indentation and
-- content. Lines without a marker are left untouched.
local function strip_marker(line)
  if line:match('^%s*$') then return line end
  local indent, marker, content = split_line(line)
  if marker then return indent .. content end
  return line
end

-- Apply `transform` to every line in the current visual selection, then leave
-- visual mode and reselect the same lines linewise.
local function transform_selection(transform)
  local first = vim.fn.line('v')
  local last = vim.fn.line('.')
  if first > last then
    first, last = last, first
  end

  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  for i, line in ipairs(lines) do
    lines[i] = transform(line)
  end
  vim.api.nvim_buf_set_lines(0, first - 1, last, false, lines)

  -- Leave visual mode so the reselect starts from a clean state, then reselect
  -- the same line range linewise for the global `>` / `<` mappings.
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
  vim.api.nvim_feedkeys(esc, 'nx', false)
  vim.cmd(string.format('normal! %dGV%dG', first, last))
end

local map = vim.keymap.set
local opts = { buffer = true, silent = true }

map(
  'v',
  '<localleader>lb',
  function() transform_selection(to_bullet) end,
  vim.tbl_extend('force', opts, { desc = 'Markdown: To Unordered List' })
)
map(
  'v',
  '<localleader>ln',
  function() transform_selection(to_ordered) end,
  vim.tbl_extend('force', opts, { desc = 'Markdown: To Ordered List' })
)
map(
  'v',
  '<localleader>lr',
  function() transform_selection(strip_marker) end,
  vim.tbl_extend('force', opts, { desc = 'Markdown: Remove List Marker' })
)
-- ------------------------------------------------------------------------- }}}
