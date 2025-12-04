return {
  'code-biscuits/nvim-biscuits',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
  },
  config = function()
    require('nvim-biscuits').setup({
      show_on_start = false,
      cursor_line_only = true,
    })

    vim.keymap.set('n', '<leader>tb', function()
      local nvim_biscuits = require('nvim-biscuits')
      nvim_biscuits.BufferAttach()
      nvim_biscuits.toggle_biscuits()
    end, { desc = 'Enable Biscuits' })
  end,
}
