return {
  'akinsho/bufferline.nvim',
  event = 'VeryLazy',
  keys = {
    { '<leader>btp', '<Cmd>BufferLineTogglePin<CR>', desc = 'Toggle Pin' },
    { '<leader>btP', '<Cmd>BufferLineGroupClose ungrouped<CR>', desc = 'Close Non-Pinned Buffers' },
    { '<leader>bco', '<Cmd>BufferLineCloseOthers<CR>', desc = 'Close Other Buffers' },
    { '<leader>bcr', '<Cmd>BufferLineCloseRight<CR>', desc = 'Close Buffers to the Right' },
    { '<leader>bcl', '<Cmd>BufferLineCloseLeft<CR>', desc = 'Close Buffers to the Left' },
    { '<leader>bp', '<Cmd>BufferLinePick<CR>', desc = 'Pick Buffer' },
    { '<S-h>', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev Buffer' },
    { '<S-l>', '<cmd>BufferLineCycleNext<cr>', desc = 'Next Buffer' },
    { '[b', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev Buffer' },
    { ']b', '<cmd>BufferLineCycleNext<cr>', desc = 'Next Buffer' },
    { '[B', '<cmd>BufferLineMovePrev<cr>', desc = 'Move buffer prev' },
    { ']B', '<cmd>BufferLineMoveNext<cr>', desc = 'Move buffer next' },
  },
  config = function()
    require('bufferline').setup({
      options = {
        always_show_bufferline = false,
        separator_style = 'thin',
      },
    })
  end,
}
