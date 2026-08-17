---@module 'lazy'
---@type LazySpec
return {
  'echasnovski/mini.align',
  event = 'VeryLazy',
  config = function()
    -- mini.align's `setup()` installs the standard interactive mappings and
    -- attaches its own descriptions ("Align" for `ga`, "Align with preview"
    -- for `gA`), so keep defaults and let the module own the keymaps.
    require('mini.align').setup({
      mappings = {
        start = 'ga',
        start_with_preview = 'gA',
      },
    })
  end,
}
