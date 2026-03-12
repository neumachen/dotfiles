local Lsp = require('utils.lsp')

---Returns true when biome.json exists and is NOT inside the nvim config dir
local function use_biome()
  local path = Lsp.biome_config_path()
  return path ~= nil and not string.match(path, 'nvim')
end

---Returns true when prettier/prettierd should be used (i.e. biome is absent)
local function use_prettier() return not use_biome() end

---Run the first available formatter followed by more formatters
---@param bufnr integer
---@param ... string
---@return string
local function first(bufnr, ...)
  local conform = require('conform')
  for i = 1, select('#', ...) do
    local formatter = select(i, ...)
    if conform.get_formatter_info(formatter, bufnr).available then
      return formatter
    end
  end
  return select(1, ...)
end

return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    { '<leader>cn', '<cmd>ConformInfo<cr>', desc = 'Conform Info' },
  },
  opts = {
    format_on_save = {
      lsp_format = 'fallback',
      timeout_ms = 500,
    },
    format_after_save = {
      lsp_format = 'fallback',
    },
    notify_on_error = true,
    notify_no_formatters = true,
    formatters_by_ft = {
      dockerfile = { 'dockerfmt' },
      lua = { 'stylua' },
      go = { 'goimports', 'gofumpt' },
      python = function(bufnr)
        if
          require('conform').get_formatter_info('ruff_format', bufnr).available
        then
          return { 'ruff_format' }
        else
          return { 'isort', 'black' }
        end
      end,
      ruby = { 'rubocop' },
      json = { 'biome', 'dprint', stop_after_first = true },
      markdown = { 'prettierd', 'prettier', 'dprint', stop_after_first = true },
      ['markdown.mdx'] = {
        'prettierd',
        'prettier',
        'dprint',
        stop_after_first = true,
      },
      javascript = {
        'biome',
        'deno_fmt',
        'prettierd',
        'prettier',
        'dprint',
        stop_after_first = true,
      },
      javascriptreact = function(bufnr)
        return {
          'rustywind',
          first(bufnr, 'biome', 'deno_fmt', 'prettierd', 'prettier', 'dprint'),
        }
      end,
      typescript = {
        'biome',
        'deno_fmt',
        'prettierd',
        'prettier',
        'dprint',
        stop_after_first = true,
      },
      typescriptreact = function(bufnr)
        return {
          'rustywind',
          first(bufnr, 'biome', 'deno_fmt', 'prettierd', 'prettier', 'dprint'),
        }
      end,
      svelte = function(bufnr)
        return {
          'rustywind',
          first(bufnr, 'biome', 'deno_fmt', 'prettierd', 'prettier', 'dprint'),
        }
      end,
      html = { 'prettierd', 'prettier', stop_after_first = true },
      css = { 'prettierd', 'prettier', stop_after_first = true },
      scss = { 'prettierd', 'prettier', stop_after_first = true },
      yaml = { 'prettierd', 'prettier', stop_after_first = true },
      toml = { 'taplo' },
      sql = { 'sql_formatter', 'sqlfluff', stop_after_first = true },
      sh = { 'shfmt' },
      bash = { 'shfmt' },
      zsh = { 'shfmt' },
    },
    formatters = {
      biome = { condition = use_biome },
      deno_fmt = { condition = function() return Lsp.deno_config_exist() end },
      dprint = { condition = function() return Lsp.dprint_config_exist() end },
      prettier = { condition = use_prettier },
      prettierd = { condition = use_prettier },
    },
    default_format_opts = {
      lsp_format = 'fallback',
    },
  },
  init = function() vim.o.formatexpr = "v:lua.require'conform'.formatexpr()" end,
}
