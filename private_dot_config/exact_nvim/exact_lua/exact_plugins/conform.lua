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

---Manual "Format as…" presets. Each entry maps a human label to a fallback
---chain of conform formatters; the first one available on $PATH wins.
---Used by `<leader>cF` to format the whole buffer or a visual selection
---regardless of the buffer's filetype (handy for scratch buffers, kulala
---scratchpads, or a JSON blob embedded inside a Lua/Go/Python comment).
---@type { label: string, formatters: string[], filetypes: string[] }[]
local format_as = {
  {
    label = 'JSON',
    formatters = { 'biome', 'prettierd', 'prettier', 'dprint', 'jq' },
    filetypes = { 'json', 'jsonc', 'json5' },
  },
  {
    label = 'YAML',
    formatters = { 'prettierd', 'prettier', 'yamlfmt' },
    filetypes = { 'yaml' },
  },
  { label = 'TOML', formatters = { 'taplo' }, filetypes = { 'toml' } },
  {
    label = 'JS/TS',
    formatters = { 'biome', 'deno_fmt', 'prettierd', 'prettier', 'dprint' },
    filetypes = {
      'javascript',
      'javascriptreact',
      'typescript',
      'typescriptreact',
      'svelte',
    },
  },
  {
    label = 'HTML',
    formatters = { 'prettierd', 'prettier' },
    filetypes = { 'html' },
  },
  {
    label = 'CSS',
    formatters = { 'prettierd', 'prettier' },
    filetypes = { 'css', 'scss' },
  },
  {
    label = 'Markdown',
    formatters = { 'prettierd', 'prettier', 'dprint' },
    filetypes = { 'markdown', 'markdown.mdx', 'markdown.mdc' },
  },
  {
    label = 'SQL',
    formatters = { 'sql_formatter', 'sqlfluff' },
    filetypes = { 'sql' },
  },
  { label = 'Lua', formatters = { 'stylua' }, filetypes = { 'lua' } },
  -- Terraform / OpenTofu / HCL. `terraform_fmt` is the conform built-in
  -- that shells out to `terraform fmt -`. `tofu_fmt` does the same with
  -- OpenTofu; listed second so it's the fallback when terraform isn't on
  -- $PATH (per TERRAFORM-01-CORE-STYLE.mdc, both are first-class). The
  -- `hcl` filetype covers Packer / Waypoint / Nomad / Boundary HCL — same
  -- formatter works since they share the format.
  {
    label = 'Terraform / HCL',
    formatters = { 'terraform_fmt', 'tofu_fmt' },
    filetypes = { 'terraform', 'terraform-vars', 'hcl' },
  },
  {
    label = 'Shell',
    formatters = { 'shfmt' },
    filetypes = { 'sh', 'bash', 'zsh' },
  },
  {
    label = 'Python',
    formatters = { 'ruff_format', 'black' },
    filetypes = { 'python' },
  },
  {
    label = 'Go',
    formatters = { 'goimports', 'gofumpt' },
    filetypes = { 'go' },
  },
  {
    label = 'XML',
    formatters = { 'xmlformatter', 'prettier' },
    filetypes = { 'xml' },
  },
}

---Returns a copy of `format_as` rotated so the entry matching `ft` is first.
---@param ft string
---@return { label: string, formatters: string[], filetypes: string[] }[]
local function prioritize(ft)
  local head, tail = {}, {}
  for _, entry in ipairs(format_as) do
    if ft ~= '' and vim.tbl_contains(entry.filetypes, ft) then
      table.insert(head, entry)
    else
      table.insert(tail, entry)
    end
  end
  return vim.list_extend(head, tail)
end

---Open a picker and run conform with the chosen formatter chain.
---@param mode 'n'|'x'
local function format_as_picker(mode)
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype or ''
  local ordered = prioritize(ft)

  -- Capture visual range BEFORE ui.select, because opening the picker leaves
  -- visual mode and the '<,'> marks may otherwise be stale by the callback.
  local range
  if mode == 'x' then
    -- Leave visual mode so '<,'> marks are written, then read the range.
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes('<Esc>', true, false, true),
      'nx',
      false
    )
    local s = vim.fn.getpos("'<")
    local e = vim.fn.getpos("'>")
    range = { start = { s[2], s[3] - 1 }, ['end'] = { e[2], e[3] } }
  end

  vim.ui.select(ordered, {
    prompt = 'Format as:',
    format_item = function(item)
      if ft ~= '' and vim.tbl_contains(item.filetypes, ft) then
        return item.label .. '  (matches filetype: ' .. ft .. ')'
      end
      return item.label
    end,
  }, function(choice)
    if not choice then return end
    local opts = {
      formatters = choice.formatters,
      lsp_format = 'never',
      stop_after_first = true,
    }
    if range then
      -- Range formatting must be synchronous; positions would otherwise drift.
      opts.range = range
      opts.async = false
      opts.timeout_ms = 3000
    else
      opts.async = true
    end
    require('conform').format(opts, function(err)
      if err then
        vim.notify(
          'Format as ' .. choice.label .. ' failed: ' .. tostring(err),
          vim.log.levels.ERROR,
          { title = 'conform: format-as' }
        )
      end
    end)
  end)
end

return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    { '<leader>cn', '<cmd>ConformInfo<cr>', desc = 'Conform Info' },
    {
      '<leader>cF',
      function() format_as_picker('n') end,
      mode = 'n',
      desc = 'Format as… (buffer)',
    },
    {
      '<leader>cF',
      function() format_as_picker('x') end,
      mode = 'x',
      desc = 'Format as… (selection)',
    },
  },
  opts = {
    format_on_save = function(bufnr)
      local conform = require('conform')
      local formatters = conform.list_formatters(bufnr)
      if #formatters > 0 then
        local to_run, will_use_lsp = conform.list_formatters_to_run(bufnr)
        if #to_run == 0 and not will_use_lsp then
          local names = table.concat(
            vim.tbl_map(function(f) return f.name end, formatters),
            ', '
          )
          vim.notify(
            '['
              .. vim.bo[bufnr].filetype
              .. '] No formatter available.\nConfigured: '
              .. names
              .. '\nInstall one or check :ConformInfo',
            vim.log.levels.ERROR,
            { title = 'conform: no formatter' }
          )
          return nil
        end
      end
      return { timeout_ms = 500 }
    end,
    format_after_save = {},
    notify_on_error = true,
    notify_no_formatters = false,
    -- JS/TS stack overlap (intentional, runtime-guarded; flagged for review):
    --   * formatter chain: biome → deno_fmt → prettierd → prettier → dprint
    --     (gated by use_biome / deno_config_exist / dprint_config_exist /
    --     use_prettier in `formatters` below)
    --   * LSP: `biome` LSP + `eslint` LSP
    --   * linters (nvim-lint.lua): `oxlint` + `eslint_d`
    -- `dprint` is a dead branch right now — not provisioned in mise/Brewfile,
    -- and gated by an absent `dprint.json`. Keep until a canonical JS/TS
    -- formatter is chosen and the rest is consolidated.
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
      -- BEAM languages: `mix` is a built-in conform formatter that shells out
      -- to `mix format -`; erlfmt is a standalone escript (see
      -- exact_mise/exact_conf.d/60-github.toml for the provisioning note).
      elixir = { 'mix' },
      eelixir = { 'mix' },
      heex = { 'mix' },
      erlang = { 'erlfmt' },
      json = {
        'biome',
        'dprint',
        'prettierd',
        'prettier',
        stop_after_first = true,
      },
      markdown = { 'prettierd', 'prettier', 'dprint', stop_after_first = true },
      ['markdown.mdx'] = {
        'prettierd',
        'prettier',
        'dprint',
        stop_after_first = true,
      },
      ['markdown.mdc'] = {
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
      -- Terraform / OpenTofu / HCL. `stop_after_first = true` so we don't
      -- run `terraform fmt` followed by `tofu fmt` on the same buffer.
      terraform = { 'terraform_fmt', 'tofu_fmt', stop_after_first = true },
      ['terraform-vars'] = {
        'terraform_fmt',
        'tofu_fmt',
        stop_after_first = true,
      },
      hcl = { 'terraform_fmt', 'tofu_fmt', stop_after_first = true },
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
    default_format_opts = {},
  },
  init = function() vim.o.formatexpr = "v:lua.require'conform'.formatexpr()" end,
}
