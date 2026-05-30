return {
  'rasulomaroff/reactive.nvim',
  event = 'VeryLazy',
  config = function()
    require('reactive').setup({
      builtin = {
        cursorline = true,
        cursor = true,
        modemsg = true,
      },
    })
  end,
}
