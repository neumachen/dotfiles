local highlight = as.highlight

return {
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    event = { 'VeryLazy' },
    -- lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
    init = function(plugin)
      -- PERF: add nvim-treesitter queries to the rtp and it's custom query predicates early
      -- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
      -- no longer trigger the **nvim-treesitter** module to be loaded in time.
      -- Luckily, the only things that those plugins need are the custom queries, which we make available
      -- during startup.
      require('lazy.core.loader').add_to_rtp(plugin)
      require('nvim-treesitter.query_predicates')
    end,
    opts = {
      ensure_installed = {
        'bash',
        'c',
        'cmake',
        'cpp',
        'css',
        'csv',
        'diff',
        'dockerfile',
        'editorconfig',
        'elixir',
        'erlang',
        'git_config',
        'git_rebase',
        'gleam',
        'go',
        'goctl',
        'gomod',
        'gosum',
        'gotmpl',
        'gowork',
        'gpg',
        'haskell',
        'helm',
        'html',
        'hurl',
        'javascript',
        'jsdoc',
        'json',
        'jsonc',
        'just',
        'lua',
        'luadoc',
        'luap',
        'markdown',
        'markdown_inline',
        'printf',
        'proto',
        'python',
        'query',
        'regex',
        'regex',
        'ruby',
        'rust',
        'ssh_config',
        'toml',
        'tsx',
        'typescript',
        'typescript',
        'vim',
        'vimdoc',
        'xml',
        'yaml',
      },
      sync_install = false,
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = { 'sql' },
      },
      incremental_selection = {
        enable = true,
        disable = { 'help' },
        keymaps = {
          init_selection = '<CR>', -- maps in normal mode to init the node/scope selection
          node_incremental = '<CR>', -- increment to the upper named parent
          node_decremental = '<C-CR>', -- decrement to the previous node
        },
      },
      indent = {
        enable = true,
        disable = { 'yaml' },
      },
      textobjects = {
        lookahead = true,
        select = {
          enable = true,
          include_surrounding_whitespace = true,
          keymaps = {
            ['af'] = { query = '@function.outer', desc = 'ts: all function' },
            ['if'] = { query = '@function.inner', desc = 'ts: inner function' },
            ['ac'] = { query = '@class.outer', desc = 'ts: all class' },
            ['ic'] = { query = '@class.inner', desc = 'ts: inner class' },
            ['aC'] = { query = '@conditional.outer', desc = 'ts: all conditional' },
            ['iC'] = { query = '@conditional.inner', desc = 'ts: inner conditional' },
            ['aL'] = { query = '@assignment.lhs', desc = 'ts: assignment lhs' },
            ['aR'] = { query = '@assignment.rhs', desc = 'ts: assignment rhs' },
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = { [']m'] = '@function.outer', [']M'] = '@class.outer' },
          goto_previous_start = { ['[m'] = '@function.outer', ['[M'] = '@class.outer' },
        },
      },
      autopairs = { enable = true },
      playground = { persist_queries = true },
      query_linter = {
        enable = true,
        use_virtual_text = true,
        lint_events = { 'BufWrite', 'CursorHold' },
      },
    },
    config = function(_, opts)
      local parser_config = require('nvim-treesitter.parsers').get_parser_configs()
      parser_config.d2 = {
        install_info = {
          url = 'https://github.com/ravsii/tree-sitter-d2',
          files = { 'src/parser.c' },
          branch = 'main',
        },
        filetype = 'd2',
      }
      require('nvim-treesitter.configs').setup(opts)
    end,
    dependencies = {
      { 'nvim-treesitter/nvim-treesitter-textobjects' },
    },
  },
  { 'JoosepAlviste/nvim-ts-context-commentstring' },
  {
    'windwp/nvim-ts-autotag',
    ft = {
      'typescriptreact',
      'javascript',
      'javascriptreact',
      'html',
      'vue',
    },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = true,
  },
  {
    'nvim-treesitter/playground',
    cmd = { 'TSPlaygroundToggle' },
    dependencies = { 'nvim-treesitter' },
  },
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = 'VeryLazy',
    init = function()
      highlight.plugin('treesitter-context', {
        { TreesitterContextSeparator = { link = 'Dim' } },
        { TreesitterContext = { inherit = 'Normal' } },
        { TreesitterContextLineNumber = { inherit = 'LineNr' } },
      })
    end,
    opts = {
      multiline_threshold = 4,
      separator = '─', -- alternatives: ▁ ─ ▄
      mode = 'cursor',
    },
  },
}
