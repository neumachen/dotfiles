return {
  {
    'tadaa/vimade',
    config = function()
      require('vimade').setup({
        recipe = { 'default', { animate = true } },
        fadelevel = 0.4,
      })
    end,
  },
}
