-- utils.doctor
--
-- Mason-free "missing tool" doctor. Inspects:
--   1. conform.nvim formatters_by_ft (via require('conform').formatters_by_ft)
--   2. nvim-lint linters_by_ft       (via require('lint').linters_by_ft)
--   3. LSP server cmds               (every <config>/lsp/*.lua → cmd[1])
--
-- For each referenced binary, runs `vim.fn.executable()` and produces a single
-- notification listing whatever is missing, grouped by source. No external
-- dependencies, no install logic, no autostart side-effects.
--
-- Usage:
--   :ToolDoctor              -- run the check, single notification
--   :checkhealth utils.doctor -- same check, in the :checkhealth UI
--
-- Extend `M.alias` below when a tool's executable name differs from its
-- formatter/linter name (e.g. ruff_format → ruff).

local M = {}

---@type table<string, string|false>
---Maps conform-formatter / nvim-lint-linter names to their executable name.
---Use `false` to mark a name as "no real binary" (in-process / handled by the
---host LSP) so it gets skipped instead of flagged as missing.
M.alias = {
  -- conform formatters where the formatter name ≠ binary name
  ruff_format = 'ruff',
  deno_fmt = 'deno',
  -- nvim-lint linters where the linter name ≠ binary name
  golangcilint = 'golangci-lint',
}

---@param name string
---@return string|nil binary  -- nil means "skip; no executable to check"
local function resolve(name)
  local v = M.alias[name]
  if v == false then return nil end
  return v or name
end

---@param fn function
---@return string[]|nil
local function safe_call_formatter_fn(fn)
  local ok, result = pcall(fn, 0) -- bufnr=0 = current buffer
  if not ok or type(result) ~= 'table' then return nil end
  return result
end

---Collects formatter binary names from conform's spec.
---@return string[] missing
local function check_conform()
  local ok, conform = pcall(require, 'conform')
  if not ok then return {} end
  local seen, missing = {}, {}
  local by_ft = conform.formatters_by_ft or {}
  for _, entry in pairs(by_ft) do
    local list = entry
    if type(entry) == 'function' then list = safe_call_formatter_fn(entry) end
    if type(list) == 'table' then
      for _, name in ipairs(list) do
        if type(name) == 'string' then
          local bin = resolve(name)
          if bin and not seen[bin] then
            seen[bin] = true
            if vim.fn.executable(bin) ~= 1 then
              table.insert(missing, name)
            end
          end
        end
      end
    end
  end
  table.sort(missing)
  return missing
end

---Collects linter binary names from nvim-lint's spec.
---@return string[] missing
local function check_lint()
  local ok, lint = pcall(require, 'lint')
  if not ok then return {} end
  local seen, missing = {}, {}
  local by_ft = lint.linters_by_ft or {}
  for _, list in pairs(by_ft) do
    if type(list) == 'table' then
      for _, name in ipairs(list) do
        if type(name) == 'string' then
          local bin = resolve(name)
          if bin and not seen[bin] then
            seen[bin] = true
            if vim.fn.executable(bin) ~= 1 then
              table.insert(missing, name)
            end
          end
        end
      end
    end
  end
  table.sort(missing)
  return missing
end

---Walks the configured `lsp/` dir (where vim.lsp.enable() loads from on 0.11+).
---For each `<server>.lua`, dofile it, read its `cmd[1]`, and check that
---binary. Skips files that error or have no `cmd`.
---@return string[] missing
local function check_lsp()
  local lsp_dir = vim.fn.stdpath('config') .. '/lsp'
  if vim.fn.isdirectory(lsp_dir) ~= 1 then return {} end
  local seen, missing = {}, {}
  for name, type_ in vim.fs.dir(lsp_dir) do
    if type_ == 'file' and name:match('%.lua$') then
      local path = lsp_dir .. '/' .. name
      local ok, spec = pcall(dofile, path)
      if ok and type(spec) == 'table' and type(spec.cmd) == 'table' then
        local bin = spec.cmd[1]
        if type(bin) == 'string' and not seen[bin] then
          seen[bin] = true
          if vim.fn.executable(bin) ~= 1 then
            table.insert(missing, name:gsub('%.lua$', '') .. ' (' .. bin .. ')')
          end
        end
      end
    end
  end
  table.sort(missing)
  return missing
end

---Runs all three checks and emits a single notification.
---@param opts? { silent?: boolean }
function M.run(opts)
  opts = opts or {}
  local formatters = check_conform()
  local linters = check_lint()
  local lsps = check_lsp()

  local total = #formatters + #linters + #lsps
  if total == 0 then
    if not opts.silent then
      vim.notify(
        'ToolDoctor: all referenced formatters, linters, and LSP servers are installed.',
        vim.log.levels.INFO,
        { title = 'ToolDoctor' }
      )
    end
    return { formatters = {}, linters = {}, lsps = {} }
  end

  local parts = {}
  if #formatters > 0 then
    table.insert(
      parts,
      'Formatters (conform): ' .. table.concat(formatters, ', ')
    )
  end
  if #linters > 0 then
    table.insert(parts, 'Linters (nvim-lint): ' .. table.concat(linters, ', '))
  end
  if #lsps > 0 then
    table.insert(parts, 'LSP servers: ' .. table.concat(lsps, ', '))
  end
  vim.notify(
    'ToolDoctor — missing tools:\n  ' .. table.concat(parts, '\n  '),
    vim.log.levels.WARN,
    { title = 'ToolDoctor' }
  )

  return { formatters = formatters, linters = linters, lsps = lsps }
end

---@class utils.doctor.SetupOpts
---@field cmd? boolean       -- register :ToolDoctor user-command (default true)

---Registers :ToolDoctor. Does NOT auto-run at startup.
---@param opts? utils.doctor.SetupOpts
function M.setup(opts)
  opts = opts or {}
  if opts.cmd ~= false then
    vim.api.nvim_create_user_command(
      'ToolDoctor',
      function() M.run() end,
      { desc = 'Check for missing formatter / linter / LSP binaries' }
    )
  end
end

return M
