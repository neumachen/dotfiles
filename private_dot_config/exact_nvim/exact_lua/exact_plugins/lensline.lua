-- DISABLED (Phase A6, nvim-review): trialing life without code-lens. Re-enable by
-- removing the surrounding `--[[ ... ]]` block-comment and deleting the `return {}` line.
-- If unused after ~1 week, delete this file outright.
return {}

--[[
return {
  'oribarilan/lensline.nvim',
  event = 'LspAttach',
  config = function()
    require('lensline').setup({
      -- PROFILE definitions, first is default
      profiles = {
        {
          name = 'basic',
          providers = {
            {
              name = 'usages',
              enabled = true,
              include = { 'refs' },
              breakdown = false,
            },
            { name = 'last_author', enabled = true },
          },
          style = { render = 'all', placement = 'above' },
        },
        {
          name = 'informative',
          providers = {
            {
              name = 'usages',
              enabled = true,
              include = { 'refs', 'defs', 'impls' },
              breakdown = true,
            },
            { name = 'diagnostics', enabled = true, min_level = 'HINT' },
            { name = 'complexity', enabled = true },
          },
          style = { render = 'focused', placement = 'inline' },
        },
      },
    })
  end,
}
]]
