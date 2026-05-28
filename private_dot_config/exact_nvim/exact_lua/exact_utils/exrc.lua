-- Helpers for Neovim's built-in project-local config (`:h 'exrc'`).
--
-- `exrc` makes Neovim load `.nvim.lua`, `.nvimrc`, or `.exrc` from any
-- ancestor of the file being edited, gated behind a per-file trust prompt
-- (`:h trust`). This module exposes a picker over the loadable hierarchy
-- plus scaffold/trust/delete helpers that take a uniform scope argument.
--
-- Exposed user commands (registered in M.setup):
--   :ExrcEdit   [home]            Picker over the buffer's ancestor hierarchy.
--                                 With `home`, widens the walk past the git
--                                 toplevel up to $HOME.
--   :ExrcNew    [scope|path]      Create a new exrc file. Scope keywords:
--                                   (no arg) → directory of current buffer
--                                   project  → git root (cwd if no repo)
--                                   home     → $HOME
--                                 Anything else is treated as an absolute or
--                                 relative directory path. `!` overwrites.
--   :ExrcTrust  [scope]           Without args, picker over existing exrc
--                                 files in the hierarchy. With `project` or
--                                 `home`, runs `:trust` on that file
--                                 directly (errors if it does not exist).
--   :ExrcDelete [scope] [!]       Symmetric with :ExrcTrust; deletes after
--                                 confirmation. `!` skips confirm.
--
-- All four commands are also registered as `:Nvimrc*` aliases.

local M = {}

-- The filenames Neovim's `exrc` scans for, in load priority order. See
-- `:h 'exrc'`.
local EXRC_FILENAMES = { '.nvim.lua', '.nvimrc', '.exrc' }

-- Filename used when creating a new exrc file. `.nvim.lua` is the modern,
-- Lua-native choice and the one Neovim looks for first.
local DEFAULT_NEW_FILENAME = '.nvim.lua'

---Notify with a stable title so notifications group cleanly.
---@param msg string
---@param level integer|nil
local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'exrc' })
end

---Return the directory we anchor the hierarchy walk at.
---Prefers the current buffer's file path; falls back to cwd for empty or
---special buffers (no name, `buftype` non-empty).
---@return string absolute directory path
local function anchor_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' or vim.bo.buftype ~= '' then return vim.fn.getcwd() end
  return vim.fn.fnamemodify(name, ':p:h')
end

---Resolve the git toplevel of `start_dir`, or nil if `start_dir` is not in a
---repo. Avoids the cwd-dependent `utils.path.get_git_root` so we can resolve
---roots for arbitrary paths.
---@param start_dir string
---@return string|nil absolute directory path or nil
local function git_root(start_dir)
  local result = vim
    .system({ 'git', '-C', start_dir, 'rev-parse', '--show-toplevel' }, {
      text = true,
    })
    :wait()
  if result.code == 0 then
    local root = (result.stdout or ''):gsub('\n$', '')
    if root ~= '' then return root end
  end
  return nil
end

---Walk from `start_dir` upward, returning every ancestor directory.
---* When `widen_to_home` is false (default) and `start_dir` is inside a git
---  repo, stops at the repo toplevel (inclusive).
---* When `widen_to_home` is true, or when not inside a repo, stops at
---  `$HOME` (inclusive).
---* When `start_dir` is outside `$HOME` and not in a repo, walks to `/`.
---@param start_dir string
---@param widen_to_home boolean|nil
---@return string[] ordered list of absolute directories, closest-first
local function hierarchy(start_dir, widen_to_home)
  local home = vim.fn.expand('~')
  local stop_at
  if widen_to_home then
    stop_at = home
  else
    stop_at = git_root(start_dir) or home
  end

  local dirs = {}
  local current = vim.fn.fnamemodify(start_dir, ':p'):gsub('/$', '')
  local seen = {}

  while current and current ~= '' and not seen[current] do
    seen[current] = true
    table.insert(dirs, current)

    if current == stop_at then break end
    if current == '/' then break end

    local parent = vim.fn.fnamemodify(current, ':h')
    if parent == current then break end
    current = parent
  end

  return dirs
end

---Return the first existing exrc filename in `dir`, or nil if none.
---@param dir string
---@return string|nil filename (e.g. ".nvim.lua")
---@return string|nil absolute path
local function existing_exrc(dir)
  for _, name in ipairs(EXRC_FILENAMES) do
    local full = dir .. '/' .. name
    if vim.fn.filereadable(full) == 1 then return name, full end
  end
  return nil, nil
end

---Replace a leading `$HOME` with `~` for display.
---@param dir string
---@return string
local function pretty(dir)
  local home = vim.fn.expand('~')
  return (dir:gsub('^' .. vim.pesc(home), '~'))
end

---Build picker entries for the buffer's hierarchy. Existing exrc files are
---listed alongside "(create)" placeholders for empty ancestors so the same
---picker can serve both edit-existing and scaffold-new flows.
---@param widen_to_home boolean|nil
---@return table[] entries closest-first; each { dir, path, exists, label }
local function scan_hierarchy(widen_to_home)
  local entries = {}
  for _, dir in ipairs(hierarchy(anchor_dir(), widen_to_home)) do
    local name, full = existing_exrc(dir)
    if name then
      table.insert(entries, {
        dir = dir,
        path = full,
        exists = true,
        label = string.format('  %s/%s', pretty(dir), name),
      })
    else
      local path = dir .. '/' .. DEFAULT_NEW_FILENAME
      table.insert(entries, {
        dir = dir,
        path = path,
        exists = false,
        label = string.format(
          '  %s/%s (create)',
          pretty(dir),
          DEFAULT_NEW_FILENAME
        ),
      })
    end
  end
  return entries
end

---Resolve a scope keyword or path to an absolute directory.
---  (nil/"")  → anchor_dir() (current buffer's dir)
---  "project" → git root of anchor, or cwd if no repo
---  "home"    → $HOME
---  any other → treated as a path (expanded, made absolute)
---@param scope string|nil
---@return string|nil dir, string|nil err
local function resolve_scope(scope)
  if scope == nil or scope == '' then return anchor_dir() end
  if scope == 'project' then
    return git_root(anchor_dir()) or vim.fn.getcwd()
  end
  if scope == 'home' then return vim.fn.expand('~') end

  local expanded = vim.fn.fnamemodify(vim.fn.expand(scope), ':p'):gsub('/$', '')
  if vim.fn.isdirectory(expanded) ~= 1 then
    return nil, 'not a directory: ' .. expanded
  end
  return expanded
end

---Minimal exrc stub: header, trust reminder, doc pointer. The body is left
---intentionally empty so authors decide what belongs at this level.
---@param dir string the directory the file is being created in
---@return string contents
local function stub_contents(dir)
  return table.concat({
    '-- Neovim project-local config for ' .. pretty(dir),
    '--',
    "-- Loaded by Neovim's built-in `exrc` when editing any file under this",
    '-- directory. Run `:trust` once to authorize; re-trust after every edit.',
    "-- See `:h 'exrc'` and `:h trust` for the full trust model.",
    '',
    '',
  }, '\n')
end

---Write `contents` to `path`. Returns true on success.
---@param path string
---@param contents string
---@return boolean
local function write_file(path, contents)
  local fd, err = io.open(path, 'w')
  if not fd then
    notify(
      'Failed to open ' .. path .. ': ' .. (err or '?'),
      vim.log.levels.ERROR
    )
    return false
  end
  local ok, write_err = fd:write(contents)
  fd:close()
  if not ok then
    notify(
      'Failed to write ' .. path .. ': ' .. (write_err or '?'),
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

---Find the existing exrc file at `dir`, or nil if none.
---@param dir string
---@return string|nil path
local function exrc_at(dir)
  local _, full = existing_exrc(dir)
  return full
end

---Create a new exrc file at the directory `scope` resolves to (default: the
---current buffer's directory).
---@param scope string|nil scope keyword or path; see resolve_scope
---@param opts table|nil { force: boolean }
function M.new(scope, opts)
  opts = opts or {}
  local dir, err = resolve_scope(scope)
  if not dir then
    notify(err, vim.log.levels.ERROR)
    return
  end

  local path = dir .. '/' .. DEFAULT_NEW_FILENAME
  if vim.fn.filereadable(path) == 1 and not opts.force then
    notify(
      path
        .. ' already exists. Use :ExrcNew! to overwrite, or :ExrcEdit to open.',
      vim.log.levels.WARN
    )
    return
  end

  if not write_file(path, stub_contents(dir)) then return end

  vim.cmd.edit(vim.fn.fnameescape(path))
  notify('Created ' .. path .. '. Run :trust to authorize it.')
end

---Open the picker over the buffer's exrc hierarchy. Selecting an existing
---entry edits the file; selecting a "(create)" entry scaffolds it.
---@param opts table|nil { widen_to_home: boolean }
function M.edit(opts)
  opts = opts or {}
  local entries = scan_hierarchy(opts.widen_to_home)
  if #entries == 0 then
    notify('No directories in hierarchy', vim.log.levels.WARN)
    return
  end

  vim.ui.select(entries, {
    prompt = 'exrc files (closest first)',
    format_item = function(entry) return entry.label end,
  }, function(choice)
    if not choice then return end
    if choice.exists then
      vim.cmd.edit(vim.fn.fnameescape(choice.path))
    else
      M.new(choice.dir)
    end
  end)
end

---Run `:trust` on the buffer for `path` after loading it. Returns to the
---originating buffer so the user is not displaced.
---@param path string
local function trust_path(path)
  local origin = vim.api.nvim_get_current_buf()
  vim.cmd.edit(vim.fn.fnameescape(path))
  local ok, err = pcall(vim.cmd, 'trust')
  if not ok then
    notify('trust failed: ' .. tostring(err), vim.log.levels.ERROR)
  else
    notify('Trusted ' .. path)
  end
  if vim.api.nvim_buf_is_valid(origin) then
    vim.api.nvim_set_current_buf(origin)
  end
end

---Run `:trust` on an exrc file. With no scope, opens a picker over existing
---exrc files in the buffer's hierarchy.
---@param scope string|nil
function M.trust(scope)
  if scope == nil or scope == '' then
    local entries = vim.tbl_filter(
      function(e) return e.exists end,
      scan_hierarchy()
    )
    if #entries == 0 then
      notify('No existing exrc files in hierarchy', vim.log.levels.WARN)
      return
    end
    vim.ui.select(entries, {
      prompt = 'Trust exrc file',
      format_item = function(entry) return entry.label end,
    }, function(choice)
      if choice then trust_path(choice.path) end
    end)
    return
  end

  local dir, err = resolve_scope(scope)
  if not dir then
    notify(err, vim.log.levels.ERROR)
    return
  end
  local path = exrc_at(dir)
  if not path then
    notify('No exrc file at ' .. dir, vim.log.levels.WARN)
    return
  end
  trust_path(path)
end

---Delete `path` from disk after confirmation (skippable with `force`).
---@param path string
---@param force boolean|nil
local function delete_path(path, force)
  local function do_delete()
    local ok, err = pcall(vim.fn.delete, path)
    if ok and err == 0 then
      notify('Deleted ' .. path)
    else
      notify(
        'Failed to delete ' .. path .. ': ' .. tostring(err),
        vim.log.levels.ERROR
      )
    end
  end

  if force then
    do_delete()
    return
  end
  vim.ui.select({ 'yes', 'no' }, {
    prompt = 'Delete ' .. path .. '?',
  }, function(choice)
    if choice == 'yes' then do_delete() end
  end)
end

---Delete an exrc file. With no scope, opens a picker over existing files in
---the buffer's hierarchy.
---@param scope string|nil
---@param opts table|nil { force: boolean }
function M.delete(scope, opts)
  opts = opts or {}
  if scope == nil or scope == '' then
    local entries = vim.tbl_filter(
      function(e) return e.exists end,
      scan_hierarchy()
    )
    if #entries == 0 then
      notify('No existing exrc files in hierarchy', vim.log.levels.WARN)
      return
    end
    vim.ui.select(entries, {
      prompt = 'Delete exrc file',
      format_item = function(entry) return entry.label end,
    }, function(choice)
      if choice then delete_path(choice.path, opts.force) end
    end)
    return
  end

  local dir, err = resolve_scope(scope)
  if not dir then
    notify(err, vim.log.levels.ERROR)
    return
  end
  local path = exrc_at(dir)
  if not path then
    notify('No exrc file at ' .. dir, vim.log.levels.WARN)
    return
  end
  delete_path(path, opts.force)
end

---Completion for `:ExrcEdit`: only the `home` widening keyword.
local function complete_edit(arg_lead)
  if ('home'):sub(1, #arg_lead) == arg_lead then return { 'home' } end
  return {}
end

---Completion for scope-taking commands: scope keywords + directory paths.
---@param arg_lead string
---@param cmd_line string
---@param cursor_pos integer
local function complete_scope(arg_lead, cmd_line, cursor_pos)
  local keywords = { 'project', 'home' }
  local matches = {}
  for _, kw in ipairs(keywords) do
    if kw:sub(1, #arg_lead) == arg_lead then table.insert(matches, kw) end
  end
  -- Also offer directory completion so absolute/relative paths still work.
  local dirs = vim.fn.getcompletion(arg_lead, 'dir')
  for _, d in ipairs(dirs) do
    table.insert(matches, d)
  end
  return matches
end

function M.setup()
  local function register(name, callback, command_opts)
    vim.api.nvim_create_user_command(name, callback, command_opts)
    -- Mirror as `:Nvimrc*` alias so muscle memory works both ways.
    local alias = name:gsub('^Exrc', 'Nvimrc')
    if alias ~= name then
      vim.api.nvim_create_user_command(alias, callback, command_opts)
    end
  end

  register(
    'ExrcEdit',
    function(args) M.edit({ widen_to_home = args.args == 'home' }) end,
    {
      desc = "Pick an exrc file from the buffer's hierarchy (`home` widens past git)",
      nargs = '?',
      complete = complete_edit,
    }
  )

  register(
    'ExrcNew',
    function(args)
      M.new(args.args ~= '' and args.args or nil, { force = args.bang })
    end,
    {
      desc = 'Create a new exrc file (no arg=buffer dir; project|home|<path>)',
      nargs = '?',
      bang = true,
      complete = complete_scope,
    }
  )

  register(
    'ExrcTrust',
    function(args) M.trust(args.args ~= '' and args.args or nil) end,
    {
      desc = 'Run :trust on an exrc file (no arg=picker; project|home|<path>)',
      nargs = '?',
      complete = complete_scope,
    }
  )

  register(
    'ExrcDelete',
    function(args)
      M.delete(args.args ~= '' and args.args or nil, { force = args.bang })
    end,
    {
      desc = 'Delete an exrc file (no arg=picker; project|home|<path>; `!` skips confirm)',
      nargs = '?',
      bang = true,
      complete = complete_scope,
    }
  )
end

return M
