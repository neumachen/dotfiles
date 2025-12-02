return {
  'mcauley-penney/tidy.nvim',
  config = function()
    require('tidy').setup({
      enabled_on_save = true,
      only_modified_lines = false,
      provide_undefined_editorconfig_behavior = false,
    })

    vim.keymap.set('n', '<localleader>tt', require('tidy').toggle, {
      desc = 'Toggle tidy.nvim on/off for the current buffer',
    })
    vim.keymap.set('n', '<localleader>tr', require('tidy').run, {
      desc = 'Toggle formatting functionality of tidy.nvim off without saving',
    })
  end,
}
