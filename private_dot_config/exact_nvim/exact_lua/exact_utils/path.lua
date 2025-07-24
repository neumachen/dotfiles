local M = {}

-- Joins multiple path components with the OS-appropriate path separator
-- @return string The joined path
function M.join_path(...)
  local sep = package.config:sub(1, 1) -- Gets OS path separator
  return table.concat({ ... }, sep)
end

-- Check if current directory is a git repo
---@return boolean
function M.is_git_repo()
  vim.fn.system('git rev-parse --is-inside-work-tree')
  return vim.v.shell_error == 0
end

--- Get root directory of git project
---@return string|nil
function M.get_git_root() return vim.fn.systemlist('git rev-parse --show-toplevel')[1] end

--- Get root directory of git project or fallback to current directory
---@return string|nil
function M.get_root_directory()
  if M.is_git_repo() then return M.get_git_root() end

  return vim.fn.getcwd()
end

--- Get nvim config directory
---@return string|nil
function M.get_nvim_config_directory()
  -- Returns the path to the Neovim config directory
  return vim.fn.stdpath("config")
end

--- Check if a directory exists
--- @param path string|nil The directory path to check
--- @param opts table|nil Optional configuration
---   - notify_on_missing: boolean - Show notification when directory doesn't exist
---   - notify_on_found: boolean - Show notification when directory exists
---   - notify_message: string - Custom message (uses path if not provided)
---   - notify_level: number - Log level (default: vim.log.levels.INFO)
---   - notify_title: string - Notification title (default: "Directory Check")
--- @return boolean True if the directory exists, false otherwise
function M.dir_exists(path, opts)
  if not path or path == "" then
    return false
  end

  opts = opts or {}
  local exists = vim.fn.isdirectory(vim.fn.expand(path)) == 1

  -- Handle notifications
  if (exists and opts.notify_on_found) or (not exists and opts.notify_on_missing) then
    local message = opts.notify_message or path
    local level = opts.notify_level or vim.log.levels.INFO
    local title = opts.notify_title or "Directory Check"

    if exists then
      vim.notify(string.format("Directory exists: %s", message), level, { title = title })
    else
      vim.notify(string.format("Directory not found: %s", message), level, { title = title })
    end
  end

  return exists
end

return M
