return {
  {
    'stevearc/conform.nvim',
    lazy = false,
    event = 'BufReadPre',
    opts = {
      formatters_by_ft = {
        go = { 'goimports', 'gofumpt' },
        javascript = { formatters = { 'prettierd', 'prettier' }, stop_after_first = true },
        json = { 'jq' },
        lua = { 'stylua' },
        markdown = { 'prettier' },
        pgsql = { 'sql_formatter' },
        python = { 'isort', 'black' },
        sh = { 'shfmt' },
        sql = { 'sql_formatter' },
      },
      format_on_save = {
        lsp_format = 'fallback',
        timeout_ms = 500,
      },
    },
    config = function(_, opts)
      require('conform').setup(opts)
      require('conform.formatters.sql_formatter').args = function(ctx)
        local config_path = ctx.cwd .. '/.sql-formatter.json'
        if vim.uv.fs_stat(config_path) then return { '--config', config_path } end
        return { '--language', 'postgresql' }
      end
    end,
  },
  {
    'mfussenegger/nvim-lint',
    lazy = false,
    event = 'BufReadPre',
    init = function()
      vim.api.nvim_create_autocmd({ 'TextChanged' }, {
        callback = function() require('lint').try_lint() end,
      })
    end,
    config = function()
      require('lint').linters_by_ft = {
        javascript = { 'eslint' },
        markdown = { 'markdownlint' },
        go = { 'golangcilint' },
      }
    end,
  },
  {
    'xvzc/chezmoi.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      require('chezmoi').setup({
        {
          edit = {
            watch = true,
            force = false,
          },
          notification = {
            on_open = true,
            on_apply = true,
            on_watch = true,
          },
          telescope = {
            select = { '<CR>' },
          },
        },
      })

      local telescope = require('telescope')
      vim.keymap.set(
        'n',
        '<localleader>fcn',
        function()
          telescope.extensions.chezmoi.find_files({
            targets = vim.fn.stdpath('config/nvim'),
            args = {
              '--path-style',
              'absolute',
              '--include',
              'files',
              '--exclude',
              'externals',
            },
          })
        end,
        {}
      )
      vim.keymap.set('n', '<localleader>fcd', telescope.extensions.chezmoi.find_files, {})
    end,
  },
  {
    'rest-nvim/rest.nvim',
    ft = { 'http' },
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      opts = function(_, opts)
        opts.ensure_installed = opts.ensure_installed or {}
        table.insert(opts.ensure_installed, 'http')
      end,
    },
  },
}
