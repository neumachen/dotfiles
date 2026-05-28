-- Database (vim-dadbod) helpers.
--
-- Lives alongside the vim-dadbod-ui plugin spec and exposes the functions
-- backing the <leader>d* mappings registered there. Kept here (rather than
-- inline in the plugin file) so the logic is reusable from autocmds, user
-- commands, or other plugin specs without forcing a plugin reload.

local M = {}

-- Default location for a script that prints a Dadbod-compatible Postgres URL
-- on stdout. Overridable via `vim.g.db_credential_script` or the
-- `NVIM_DB_CREDENTIAL_SCRIPT` environment variable.
local DEFAULT_SCRIPT = '~/.local/bin/get-pg-url'

-- SQL-like filetypes where vim-dadbod-completion and `vim.b.db` make sense.
local SQL_FILETYPES = {
  sql = true,
  mysql = true,
  plsql = true,
}

---Return the configured credential script path, with `~` and env vars expanded.
---Resolution order: vim.g.db_credential_script -> $NVIM_DB_CREDENTIAL_SCRIPT
----> DEFAULT_SCRIPT.
---@return string
local function resolve_script()
  local script = vim.g.db_credential_script
    or vim.env.NVIM_DB_CREDENTIAL_SCRIPT
    or DEFAULT_SCRIPT
  return vim.fn.expand(script)
end

---Whether the current buffer is a SQL-flavored buffer.
---@return boolean
local function in_sql_buffer() return SQL_FILETYPES[vim.bo.filetype] == true end

---Trim leading/trailing whitespace (including trailing newlines).
---@param s string
---@return string
local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

---Set `vim.b.db` for the current buffer if it is a SQL buffer.
---@param url string
local function maybe_set_buffer_db(url)
  if in_sql_buffer() then vim.b.db = url end
end

---Open a fresh, unsaved SQL buffer. If `vim.g.db` is set, attach it as the
---buffer-local connection so vim-dadbod-completion and `:DB` work immediately.
function M.new_sql_buffer()
  vim.cmd('enew')
  vim.bo.filetype = 'sql'
  vim.bo.buftype = 'nofile'
  vim.bo.bufhidden = 'hide'
  vim.bo.swapfile = false
  if type(vim.g.db) == 'string' and vim.g.db ~= '' then vim.b.db = vim.g.db end
end

---Attach `vim.g.db` to the current buffer as `vim.b.db`. Warns and is a no-op
---if no global connection is set, so a misfire never silently changes state.
function M.attach_current_connection()
  local url = vim.g.db
  if type(url) ~= 'string' or url == '' then
    vim.notify(
      'No vim.g.db set. Run <leader>dg or <leader>dS first.',
      vim.log.levels.WARN,
      { title = 'dadbod' }
    )
    return
  end
  vim.b.db = url
  vim.notify('Attached vim.g.db to current buffer', vim.log.levels.INFO, {
    title = 'dadbod',
  })
end

---Invoke the credential script and, on success, install the URL as the active
---Dadbod connection. The script must print a Postgres URL to stdout. On any
---failure (non-zero exit, missing script, empty output) the current connection
---is left untouched and the user is notified.
function M.generate_connection()
  local script = resolve_script()
  if vim.fn.executable(script) ~= 1 then
    vim.notify(
      string.format(
        'Credential script not executable: %s\n'
          .. 'Set vim.g.db_credential_script or $NVIM_DB_CREDENTIAL_SCRIPT.',
        script
      ),
      vim.log.levels.ERROR,
      { title = 'dadbod' }
    )
    return
  end

  local output = vim.fn.system({ script })
  local exit_code = vim.v.shell_error
  local url = trim(output or '')

  if exit_code ~= 0 or url == '' then
    vim.notify(
      string.format(
        'Credential script failed (exit=%d): %s\n%s',
        exit_code,
        script,
        url == '' and '(empty output)' or url
      ),
      vim.log.levels.ERROR,
      { title = 'dadbod' }
    )
    return
  end

  vim.g.db = url
  maybe_set_buffer_db(url)
  if not in_sql_buffer() then M.new_sql_buffer() end

  vim.notify('Database connection updated', vim.log.levels.INFO, {
    title = 'dadbod',
  })
end

---Pick an active connection. Prefers `vim.g.dbs` when populated; falls back
---to a free-form URL prompt. Sets `vim.g.db` and, if applicable, `vim.b.db`.
function M.select_connection()
  local dbs = vim.g.dbs
  local entries = {}
  if type(dbs) == 'table' then
    for name, url in pairs(dbs) do
      table.insert(entries, { name = name, url = url })
    end
    table.sort(entries, function(a, b) return a.name < b.name end)
  end

  local function apply(url)
    if type(url) ~= 'string' or url == '' then return end
    vim.g.db = url
    maybe_set_buffer_db(url)
    vim.notify('Database connection set', vim.log.levels.INFO, {
      title = 'dadbod',
    })
  end

  if #entries == 0 then
    vim.ui.input({ prompt = 'Dadbod connection URL: ' }, function(input)
      if input == nil or input == '' then
        vim.notify('Cancelled', vim.log.levels.INFO, { title = 'dadbod' })
        return
      end
      apply(input)
    end)
    return
  end

  vim.ui.select(entries, {
    prompt = 'Select database connection',
    format_item = function(item) return item.name end,
  }, function(choice)
    if not choice then return end
    apply(choice.url)
  end)
end

---Execute the entire current buffer via Dadbod.
function M.run_buffer() vim.cmd('%DB') end

---Runtime-safe keymap helper. Refuses to overwrite an existing mapping; when
---a conflict is detected the user is prompted (via vim.ui.input) for an
---alternate `lhs`. An empty/cancelled prompt skips the mapping with a notice.
---Scoped to the database mappings so existing global keymap behavior is
---unaffected.
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts table|nil
function M.safe_map(mode, lhs, rhs, opts)
  opts = opts or {}
  local modes = type(mode) == 'table' and mode or { mode }

  ---@param m string
  ---@param key string
  ---@return table|nil
  local function existing(m, key)
    local mapping = vim.fn.maparg(key, m, false, true)
    if type(mapping) == 'table' and next(mapping) ~= nil then return mapping end
    return nil
  end

  local function describe(mapping)
    local rhs_desc = mapping.rhs or mapping.callback and '<Lua callback>' or '?'
    local desc = mapping.desc and (' [' .. mapping.desc .. ']') or ''
    return tostring(rhs_desc) .. desc
  end

  local function set(key)
    for _, m in ipairs(modes) do
      vim.keymap.set(m, key, rhs, opts)
    end
  end

  for _, m in ipairs(modes) do
    local conflict = existing(m, lhs)
    if conflict then
      vim.ui.input({
        prompt = string.format(
          'Mapping %s (mode=%s) already bound to %s. Enter alternate lhs (empty to skip): ',
          lhs,
          m,
          describe(conflict)
        ),
      }, function(alt)
        if alt == nil or alt == '' then
          vim.notify(
            string.format(
              'Skipped mapping %s (%s): already bound to %s',
              lhs,
              m,
              describe(conflict)
            ),
            vim.log.levels.WARN,
            { title = 'dadbod' }
          )
          return
        end
        local alt_conflict = existing(m, alt)
        if alt_conflict then
          vim.notify(
            string.format(
              'Skipped mapping %s (%s): alternate %s also bound to %s',
              lhs,
              m,
              alt,
              describe(alt_conflict)
            ),
            vim.log.levels.WARN,
            { title = 'dadbod' }
          )
          return
        end
        vim.keymap.set(m, alt, rhs, opts)
      end)
      return
    end
  end

  set(lhs)
end

return M
