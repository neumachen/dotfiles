if not as then return end

local opt, b, fn = vim.opt_local, vim.b, vim.fn
local map = map or vim.keymap.set

opt.spell = true
opt.number = true
opt.relativenumber = true
opt.wrap = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.softtabstop = 2

map('n', '<localleader>p', '<Plug>MarkdownPreviewToggle', { desc = 'markdown preview', buffer = 0 })

b.formatting_disabled = not vim.startswith(fn.expand('%'), vim.env.MEIN_WISSEN_PATH)

as.ftplugin_conf({
  cmp = function(cmp)
    cmp.setup.filetype('markdown', {
      sources = {
        { name = 'dictionary', group_index = 1 },
        { name = 'spell', group_index = 1 },
        { name = 'emoji', group_index = 1 },
        { name = 'buffer', group_index = 2 },
      },
    })
  end,
})
