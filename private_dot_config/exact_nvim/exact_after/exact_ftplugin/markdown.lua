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

-- ------------------------------------------------------------------------- {{{
-- Markdown list continuation on open-line (buffer-local).
--
-- `o` / `O` continue the current list item: they preserve indentation and the
-- exact bullet style, restart ordered lists at `1.` (repeated `1.` is valid
-- Markdown), and always open task items with a fresh unchecked `[ ]`. On any
-- non-list line they fall back to native `o` / `O`.

-- Build the prefix for a continued list item from the current line, or return
-- nil when the current line is not a list item.
local function list_prefix(line)
  local indent, marker, content = split_line(line)
  if not marker then return nil end
  local is_task = content:match('^%[[ xX]%]') ~= nil
  local bullet = marker:match('^([-+*])')
  if bullet then
    if is_task then return indent .. bullet .. ' [ ] ' end
    return indent .. bullet .. ' '
  end
  if is_task then return indent .. '1. [ ] ' end
  return indent .. '1. '
end

-- Open a new line (`dir` is 'o' below or 'O' above) continuing the current
-- list item, or fall back to native open-line behavior for ordinary lines.
local function open_line(dir)
  local prefix = list_prefix(vim.api.nvim_get_current_line())
  if not prefix then
    vim.api.nvim_feedkeys(dir, 'in', false)
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local insert_row = dir == 'o' and row or row - 1
  vim.api.nvim_buf_set_lines(0, insert_row, insert_row, false, { prefix })
  vim.api.nvim_win_set_cursor(0, { insert_row + 1, #prefix })
  vim.cmd('startinsert!')
end

map(
  'n',
  'o',
  function() open_line('o') end,
  vim.tbl_extend('force', opts, { desc = 'Markdown: Open list item below' })
)
map(
  'n',
  'O',
  function() open_line('O') end,
  vim.tbl_extend('force', opts, { desc = 'Markdown: Open list item above' })
)
-- ------------------------------------------------------------------------- }}}
