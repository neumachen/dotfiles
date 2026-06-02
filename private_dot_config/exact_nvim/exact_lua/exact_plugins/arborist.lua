---@module "lazy"
---@type LazySpec
return {
  'arborist-ts/arborist.nvim',
  lazy = false,
  priority = 900,
  config = function()
    require('arborist').setup({
      -- Prefer WASM parsers (no per-machine toolchain required).
      prefer_wasm = true,
      -- Refresh the parser index on a weekly cadence.
      update_cadence = 'weekly',
      -- Keep arborist's curated "popular" set installed automatically.
      install_popular = true,
      -- Parsers from the previous explicit list that are NOT in the popular
      -- set. Arborist installs and keeps these up to date alongside the
      -- popular set.
      ensure_installed = {
        'cmake',
        'csv',
        'editorconfig',
        'eex',
        'elixir',
        'erlang',
        'gleam',
        'goctl',
        'gosum',
        'gotmpl',
        'gowork',
        'gpg',
        'heex',
        'hurl',
        'jsdoc',
        'just',
        'luap',
        'printf',
        'proto',
        'slim',
        'ssh_config',
      },
    })

    -- Custom predicate used by after/queries/toml/injections.scm to detect
    -- mise config files (any *mise*.toml). This is a core Neovim API
    -- (vim.treesitter.query.add_predicate) and is unrelated to the parser
    -- manager, so it must be preserved across the migration.
    vim.treesitter.query.add_predicate('is-mise?', function(_, _, bufnr, _)
      local filepath = vim.api.nvim_buf_get_name(tonumber(bufnr) or 0)
      local filename = vim.fn.fnamemodify(filepath, ':t')
      return string.match(filename, '.*mise.*%.toml$') ~= nil
    end, { force = true, all = false })

    -- There is no dedicated `jsonc` parser upstream; alias the jsonc
    -- filetype to the json5 parser (closest spec match, handles comments
    -- and trailing commas).
    vim.treesitter.language.register('json5', 'jsonc')
  end,
}
