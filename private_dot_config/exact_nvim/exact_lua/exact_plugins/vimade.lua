return {
  'tadaa/vimade',
  config = function()
    require('vimade').setup({
      recipe = { 'paradox', { animate = true } },
      fadelevel = 0.6,
    })
  end,
}
