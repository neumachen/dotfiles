-- Dockerfile presets for treesj.nvim
-- Supports splitting/joining RUN, ENV, LABEL, COPY, ADD instructions

local M = {}

--- Check if nvim-treesitter-textobjects is available
---@return boolean
local function has_textobjects()
  local ok = pcall(require, 'nvim-treesitter-textobjects')
  return ok
end

--- Get the Treesitter node at cursor using textobjects if available
---@param bufnr number
---@return TSNode|nil
local function get_instruction_node(bufnr)
  if not has_textobjects() then return nil end

  local ok, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
  if not ok then return nil end

  local node = ts_utils.get_node_at_cursor()
  if not node then return nil end

  -- Walk up to find instruction node
  while node do
    local type = node:type()
    if type:match('_instruction$') then return node end
    node = node:parent()
  end

  return nil
end

--- Build presets using treesj.langs.utils
---@return table
function M.build_presets()
  local lang_utils = require('treesj.langs.utils')

  local line_continuation = {
    split = {
      separator = ' \\\n    ',
      last_separator = false,
    },
    join = {
      separator = ' ',
    },
  }

  local shell_chain = {
    split = {
      separator = ' \\\n    && ',
      last_separator = false,
    },
    join = {
      separator = ' && ',
    },
  }

  return {
    run_instruction = lang_utils.set_preset_for_args(line_continuation),
    shell_command = lang_utils.set_preset_for_args(shell_chain),
    env_instruction = lang_utils.set_preset_for_args(line_continuation),
    label_instruction = lang_utils.set_preset_for_args(line_continuation),
    copy_instruction = lang_utils.set_preset_for_args(line_continuation),
    add_instruction = lang_utils.set_preset_for_args(line_continuation),
  }
end

--- Check if textobjects-based splitting is possible for current context
---@return boolean
function M.can_use_textobjects()
  if not has_textobjects() then return false end

  local bufnr = vim.api.nvim_get_current_buf()
  local node = get_instruction_node(bufnr)

  return node ~= nil
end

return M
