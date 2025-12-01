return {
  'rachartier/tiny-code-action.nvim',
  dependencies = {
    { 'nvim-lua/plenary.nvim' },
  },
  event = 'LspAttach',
  opts = {
    backend = 'delta',
    picker = 'snacks',
    backend_opts = {
      delta = {
        header_lines_to_remove = 4,
        args = {
          '--line-numbers',
        },
      },
    },
    resolve_timeout = 100,
    notify = {
      enabled = true, -- Enable/disable all notifications
      on_empty = true, -- Show notification when no code actions are found
    },
    signs = {
      quickfix = { '', { link = 'DiagnosticWarning' } },
      others = { '', { link = 'DiagnosticWarning' } },
      refactor = { '', { link = 'DiagnosticInfo' } },
      ['refactor.move'] = { '󰪹', { link = 'DiagnosticInfo' } },
      ['refactor.extract'] = { '', { link = 'DiagnosticError' } },
      ['source.organizeImports'] = { '', { link = 'DiagnosticWarning' } },
      ['source.fixAll'] = { '󰃢', { link = 'DiagnosticError' } },
      ['source'] = { '', { link = 'DiagnosticError' } },
      ['rename'] = { '󰑕', { link = 'DiagnosticWarning' } },
      ['codeAction'] = { '', { link = 'DiagnosticWarning' } },
    },
  },
}
