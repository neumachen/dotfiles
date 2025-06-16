local M = {}

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

return M
