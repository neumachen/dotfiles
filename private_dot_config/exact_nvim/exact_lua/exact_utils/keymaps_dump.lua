-- Helpers for exporting every Neovim keymap to JSON + Markdown for analysis.
--
-- Covers both global maps (`nvim_get_keymap`) and buffer-local maps across
-- every loaded buffer (`nvim_buf_get_keymap`), translates Neovim's internal
-- keycode bytes via `vim.fn.keytrans` so the output is valid UTF-8, and
-- annotates each entry with its which-key prefix group (mirroring the table
-- declared in plugins/which-key.lua) plus its scope (global / buffer:<ft>).
--
-- Exposed user command (registered in M.setup):
--   :DumpKeymaps [target] [!]
--     target keywords:
--       (no arg) | data        Write to stdpath('data')/keymaps-dump/
--       share                   Write to stdpath('data')/ (XDG_DATA_HOME/nvim)
--       config                  Write to stdpath('config')/keymaps-dump/
--       ask                     Prompt with vim.fn.input for a path
--       <path>                  Absolute or relative path. If it ends in
--                               .json or .md only that artifact is written.
--                               Otherwise treated as a directory and both
--                               nvim-keymaps.json and nvim-keymaps.md are
--                               written inside it.
--     !  Force-load every lazy.nvim plugin before dumping (heavy, but yields
--        the most complete capture).
--
-- Also registered as the alias `:KeymapsDump`.

local M = {}

local MODES = { 'n', 'i', 'v', 'x', 's', 'o', 'c', 't' }
local JSON_NAME = 'nvim-keymaps.json'
local MD_NAME = 'nvim-keymaps.md'

local GROUPS = {
  ['<leader>b'] = '+buffer',
  ['<leader>c'] = '+code (lsp)',
  ['<leader>d'] = '+database',
  ['<leader>f'] = '+file',
  ['<leader>g'] = '+git',
  ['<leader>gh'] = '+hunk',
  ['<leader>gl'] = '+log',
  ['<leader>gt'] = '+toggle',
  ['<leader>m'] = '+marker',
  ['<leader>n'] = '+notification',
  ['<leader>s'] = '+find/search',
  ['<leader>t'] = '+toggle',
  ['<leader>tn'] = '+neogit',
  ['<leader>ts'] = '+scooter',
  ['<leader>w'] = '+window',
  ['<leader><Tab>'] = '+tab',
  ['<localleader>c'] = '+candela',
  ['<localleader>d'] = '+diagnostics',
  ['<localleader>f'] = '+format',
  ['<localleader>g'] = '+git',
  ['<localleader>gb'] = '+buffer',
  ['<localleader>gh'] = '+hunk',
  ['<localleader>s'] = '+find/search',
  ['<localleader>t'] = '+toggle',
  ['<localleader>tn'] = '+Namu',
  ['<localleader>y'] = '+yazi',
}

---Notify with a stable title so notifications group cleanly.
---@param msg string
---@param level integer|nil
local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'keymaps_dump' })
end

---Translate Neovim's internal keycode bytes (0x80...) into readable
---<Tab>/<C-x>/... form. Falls back to the original string on error.
---@param s any
---@return any
local function readable(s)
  if type(s) ~= 'string' then return s end
  local ok, translated = pcall(vim.fn.keytrans, s)
  if ok and translated then return translated end
  return s
end

---Substitute literal leader characters at the start of an lhs with the
---tokens <leader> / <localleader> so grouping works regardless of which
---characters the user picked.
---@param lhs string
---@return string
local function normalize_lhs(lhs)
  local out = lhs
  local leader = vim.g.mapleader or '\\'
  local localleader = vim.g.maplocalleader or '\\'
  if leader ~= '' then out = out:gsub('^' .. vim.pesc(leader), '<leader>') end
  if localleader ~= '' then
    out = out:gsub('^' .. vim.pesc(localleader), '<localleader>')
  end
  return out
end

---Find the longest matching which-key prefix for an lhs.
---@param lhs_clean string
---@return string group label or 'ungrouped'
local function find_group(lhs_clean)
  local best_prefix, best_label = nil, nil
  for prefix, label in pairs(GROUPS) do
    if
      vim.startswith(lhs_clean, prefix)
      and (not best_prefix or #prefix > #best_prefix)
    then
      best_prefix, best_label = prefix, label
    end
  end
  if best_prefix then return best_prefix .. ' (' .. best_label .. ')' end
  return 'ungrouped'
end

---Build the rhs string for an entry, falling back to a callback placeholder
---when the mapping is a Lua function reference.
---@param km table
---@return string
local function rhs_of(km)
  local rhs = readable(km.rhs)
  if rhs and rhs ~= '' then return rhs end
  if km.callback then return '<lua callback>' end
  return ''
end

---Collect a single keymap entry from an `nvim_get_keymap`-style table.
---@param entries table[]
---@param seen table<string, boolean>
---@param km table
---@param mode string
---@param scope string  'global' or 'buffer:<filetype>'
---@param bufname string|nil
local function add(entries, seen, km, mode, scope, bufname)
  local lhs = readable(km.lhs)
  if type(lhs) ~= 'string' or lhs == '' then return end
  local lhs_clean = normalize_lhs(lhs)
  local dedup_key = table.concat({ mode, lhs_clean, scope }, '\0')
  if seen[dedup_key] then return end
  seen[dedup_key] = true
  table.insert(entries, {
    mode = mode,
    lhs = lhs_clean,
    rhs = rhs_of(km),
    desc = readable(km.desc) or '',
    scope = scope,
    bufname = bufname or '',
    group = find_group(lhs_clean),
  })
end

---Walk every loaded buffer and collect buffer-local maps for every mode.
---@param entries table[]
---@param seen table<string, boolean>
---@return table<string, boolean> set of filetypes observed
local function collect_buffer_maps(entries, seen)
  local filetypes = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
      local bufname = vim.api.nvim_buf_get_name(buf)
      local scope = 'buffer:' .. (ft ~= '' and ft or '?')
      filetypes[ft ~= '' and ft or '<none>'] = true
      for _, m in ipairs(MODES) do
        local ok, maps = pcall(vim.api.nvim_buf_get_keymap, buf, m)
        if ok and maps then
          for _, km in ipairs(maps) do
            add(entries, seen, km, m, scope, bufname)
          end
        end
      end
    end
  end
  return filetypes
end

---Sort entries: group, then lhs, then mode.
---@param entries table[]
local function sort_entries(entries)
  table.sort(entries, function(a, b)
    if a.group ~= b.group then return a.group < b.group end
    if a.lhs ~= b.lhs then return a.lhs < b.lhs end
    return a.mode < b.mode
  end)
end

---Force-load every plugin lazy.nvim knows about. Heavy; only invoked when
---the user passes '!' to :DumpKeymaps.
local function load_all_lazy_plugins()
  local ok, lazy = pcall(require, 'lazy')
  if not ok then
    notify('lazy.nvim not available; skipping full load', vim.log.levels.WARN)
    return
  end
  local plugins = lazy.plugins()
  notify(('loading %d lazy plugins...'):format(#plugins))
  pcall(lazy.load, { plugins = plugins })
end

---Escape a value for safe inclusion inside a Markdown table cell.
---@param s string|nil
---@return string
local function md_escape(s)
  if not s or s == '' then return '' end
  return (s:gsub('|', '\\|'):gsub('\n', ' '):gsub('\r', ''))
end

---Render entries as a grouped Markdown document.
---@param entries table[]
---@param filetypes table<string, boolean>
---@return string
local function render_markdown(entries, filetypes)
  local lines = {}
  table.insert(lines, '# Neovim keymaps')
  table.insert(lines, '')
  table.insert(
    lines,
    ('_%d mappings - generated %s - %s_'):format(
      #entries,
      os.date('%Y-%m-%d %H:%M:%S'),
      vim.fn.has('nvim-0.11') == 1 and 'nvim 0.11+' or 'nvim'
    )
  )
  table.insert(lines, '')

  local ft_list = {}
  for ft in pairs(filetypes) do
    table.insert(ft_list, ft)
  end
  table.sort(ft_list)
  if #ft_list > 0 then
    table.insert(
      lines,
      '_Buffer filetypes observed: ' .. table.concat(ft_list, ', ') .. '_'
    )
    table.insert(lines, '')
  end

  local current_group = nil
  for _, e in ipairs(entries) do
    if e.group ~= current_group then
      current_group = e.group
      table.insert(lines, '')
      table.insert(lines, '## ' .. current_group)
      table.insert(lines, '')
      table.insert(lines, '| Mode | LHS | Desc | RHS | Scope |')
      table.insert(lines, '|------|-----|------|-----|-------|')
    end
    table.insert(
      lines,
      ('| %s | `%s` | %s | `%s` | %s |'):format(
        e.mode,
        md_escape(e.lhs),
        md_escape(e.desc),
        md_escape(e.rhs),
        md_escape(e.scope)
      )
    )
  end
  table.insert(lines, '')
  return table.concat(lines, '\n')
end

---Ensure the parent directory of `path` exists.
---@param path string
---@return boolean ok, string|nil err
local function ensure_parent_dir(path)
  local dir = vim.fn.fnamemodify(path, ':h')
  if dir == '' or dir == '.' then return true end
  local ok, err = pcall(vim.fn.mkdir, dir, 'p')
  if not ok then return false, tostring(err) end
  return true
end

---Write `contents` to `path`, creating parent directories as needed.
---@param path string
---@param contents string
---@return boolean ok, string|nil err
local function write_file(path, contents)
  local parent_ok, parent_err = ensure_parent_dir(path)
  if not parent_ok then return false, parent_err end
  local f, err = io.open(path, 'w')
  if not f then return false, err end
  f:write(contents)
  f:close()
  return true
end

---Resolve a user-supplied target argument to a pair of write targets.
---@param raw string|nil  Raw argument from the command.
---@return { json: string|nil, md: string|nil }|nil, string|nil
local function resolve_target(raw)
  raw = (raw and raw ~= '') and raw or 'data'

  if raw == 'ask' then
    local input = vim.fn.input({
      prompt = 'Dump keymaps to (path or directory): ',
      default = vim.fn.stdpath('data') .. '/keymaps-dump/',
      cancelreturn = '',
      completion = 'dir',
    })
    if input == nil or input == '' then return nil, 'cancelled' end
    raw = input
  end

  local dir
  if raw == 'data' then
    dir = vim.fn.stdpath('data') .. '/keymaps-dump'
  elseif raw == 'share' then
    dir = vim.fn.stdpath('data')
  elseif raw == 'config' then
    dir = vim.fn.stdpath('config') .. '/keymaps-dump'
  else
    local expanded = vim.fn.expand(raw)
    local ext = vim.fn.fnamemodify(expanded, ':e')
    if ext == 'json' then
      return { json = expanded, md = nil }
    elseif ext == 'md' or ext == 'markdown' then
      return { json = nil, md = expanded }
    end
    dir = expanded
  end

  return {
    json = dir .. '/' .. JSON_NAME,
    md = dir .. '/' .. MD_NAME,
  }
end

---Encode a Lua value as pretty-printed JSON. Prefers vim.json.encode with
---an indent option (Neovim 0.10+); falls back to vim.fn.json_encode when the
---option is unsupported and finally to a single-line encode.
---@param value any
---@return string
local function encode_json_pretty(value)
  if vim.json and vim.json.encode then
    local ok, out = pcall(vim.json.encode, value, { indent = '  ' })
    if ok and type(out) == 'string' then return out end
    local ok2, out2 = pcall(vim.json.encode, value)
    if ok2 and type(out2) == 'string' then return out2 end
  end
  return vim.fn.json_encode(value)
end

---Core dump routine.
---@param target string|nil  Raw target argument (see :DumpKeymaps docs).
---@param opts { load_all_lazy: boolean|nil }|nil
function M.dump(target, opts)
  opts = opts or {}

  local targets, err = resolve_target(target)
  if not targets then
    notify('aborted: ' .. (err or 'unknown'), vim.log.levels.WARN)
    return
  end

  if opts.load_all_lazy then load_all_lazy_plugins() end

  local entries, seen = {}, {}
  for _, m in ipairs(MODES) do
    for _, km in ipairs(vim.api.nvim_get_keymap(m)) do
      add(entries, seen, km, m, 'global', nil)
    end
  end
  local filetypes = collect_buffer_maps(entries, seen)

  sort_entries(entries)

  local written = {}

  if targets.json then
    local ok, write_err = write_file(targets.json, encode_json_pretty(entries))
    if not ok then
      notify(
        'failed to write JSON: ' .. (write_err or '?'),
        vim.log.levels.ERROR
      )
    else
      table.insert(written, targets.json)
    end
  end

  if targets.md then
    local ok, write_err =
      write_file(targets.md, render_markdown(entries, filetypes))
    if not ok then
      notify(
        'failed to write Markdown: ' .. (write_err or '?'),
        vim.log.levels.ERROR
      )
    else
      table.insert(written, targets.md)
    end
  end

  if #written > 0 then
    notify(
      ('wrote %d mappings -> %s'):format(#entries, table.concat(written, ', '))
    )
  end
end

---Completion for :DumpKeymaps. Keywords first, then directory completion.
---@param arg_lead string
---@return string[]
local function complete(arg_lead)
  local keywords = { 'ask', 'data', 'share', 'config' }
  local matches = {}
  for _, kw in ipairs(keywords) do
    if kw:sub(1, #arg_lead) == arg_lead then table.insert(matches, kw) end
  end
  for _, d in ipairs(vim.fn.getcompletion(arg_lead, 'dir')) do
    table.insert(matches, d)
  end
  return matches
end

function M.setup()
  local function register(name)
    vim.api.nvim_create_user_command(
      name,
      function(args)
        M.dump(args.args ~= '' and args.args or nil, {
          load_all_lazy = args.bang,
        })
      end,
      {
        desc = 'Dump all keymaps to JSON+Markdown (target: ask|data|share|config|<path>; ! loads all lazy plugins first)',
        nargs = '?',
        bang = true,
        complete = complete,
      }
    )
  end

  register('DumpKeymaps')
  register('KeymapsDump')
end

return M
