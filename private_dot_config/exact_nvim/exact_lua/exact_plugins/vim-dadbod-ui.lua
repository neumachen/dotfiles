---@module "lazy"
---@type LazySpec
return {
  'kristijanhusak/vim-dadbod-ui',
  dependencies = {
    { 'tpope/vim-dadbod' },
    {
      'kristijanhusak/vim-dadbod-completion',
      ft = { 'sql', 'mysql', 'plsql' },
    },
  },
  -- Loaded eagerly so the SQL FileType autocmd and the <leader>d* mappings
  -- (registered via the runtime-safe helper in utils.db) are installed at
  -- startup, rather than only after the first DBUI command.
  event = 'VeryLazy',
  cmd = {
    'DBUI',
    'DBUIToggle',
    'DBUIAddConnection',
    'DBUIFindBuffer',
  },
  init = function()
    vim.g.db_ui_show_help = 0
    vim.g.db_ui_win_position = 'right'
    vim.g.db_ui_use_nerd_fonts = 1
    vim.g.db_ui_use_nvim_notify = 1

    vim.g.db_ui_hide_schemas = { 'pg_toast_temp.*' }

    -- Static named connections consumed by vim-dadbod-ui.
    --
    -- Real credentials MUST NOT be committed. Populate `vim.g.dbs` from one
    -- of:
    --   * environment variables read at startup
    --   * a local, git-ignored `.nvim.lua` loaded by Neovim's built-in `exrc`
    --     (see :h 'exrc' and the :ExrcNew / :ExrcEdit user commands)
    --   * the credential script wired to <leader>dg (utils.db.generate_connection)
    --
    -- Leaving `vim.g.dbs` empty is fine; DBUI will simply not show static
    -- entries until something populates it.
    if vim.g.dbs == nil then
      vim.g.dbs = {
        -- Example (commented out — do not commit real credentials):
        -- dev_local = 'postgres://user:password@localhost:5432/dev',
        -- staging   = vim.env.STAGING_DB_URL,
      }
    end

    -- When entering a SQL buffer, inherit the active global connection so
    -- `:DB`, vim-dadbod-completion, and <leader>dr work without an explicit
    -- attach step. Buffer-local `vim.b.db` already set elsewhere is honored.
    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('user_dadbod_sql', { clear = true }),
      pattern = { 'sql', 'mysql', 'plsql' },
      desc = 'Attach vim.g.db to SQL buffers when present',
      callback = function(args)
        local existing = vim.b[args.buf].db
        if
          (existing == nil or existing == '')
          and type(vim.g.db) == 'string'
          and vim.g.db ~= ''
        then
          vim.b[args.buf].db = vim.g.db
        end
      end,
    })
  end,
  config = function()
    local db = require('utils.db')
    local map = db.safe_map

    map(
      'n',
      '<leader>dt',
      '<cmd>DBUIToggle<CR>',
      { desc = 'Database: Toggle DBUI' }
    )
    map('n', '<leader>dn', db.new_sql_buffer, {
      desc = 'Database: New SQL buffer',
    })
    map('n', '<leader>dg', db.generate_connection, {
      desc = 'Database: Generate credentials from script',
    })
    map('n', '<leader>da', db.attach_current_connection, {
      desc = 'Database: Attach vim.g.db to current buffer',
    })
    map('n', '<leader>dr', db.run_buffer, {
      desc = 'Database: Run SQL buffer',
    })
    -- Visual mode runs the selected range. `:'<,'>DB` is registered directly
    -- (rather than via a Lua callback) so the `<,'>` range is supplied by Vim.
    map('v', '<leader>dr', ":'<,'>DB<CR>", {
      desc = 'Database: Run selected SQL',
      silent = true,
    })
    map('n', '<leader>dS', db.select_connection, {
      desc = 'Database: Select / set connection',
    })
  end,
}
