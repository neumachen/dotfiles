return {
  'mcauley-penney/tidy.nvim',
  event = 'BufWritePre',
  keys = {
    {
      '<localleader>tt',
      function() require('tidy').toggle() end,
      desc = 'Toggle tidy.nvim on/off for the current buffer',
    },
    {
      '<localleader>tr',
      function() require('tidy').run() end,
      desc = 'Toggle formatting functionality of tidy.nvim off without saving',
    },
  },
  config = function()
    require('tidy').setup({
      enabled_on_save = true,
      only_modified_lines = false,
      provide_undefined_editorconfig_behavior = false,
    })
  end,
}
