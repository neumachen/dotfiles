local map = vim.keymap.set

return {
  'chrisgrieser/nvim-origami',
  event = 'VeryLazy',
  config = function()
    require('origami').setup({
      useLspFoldsWithTreesitterFallback = {
        enabled = true,
        foldmethodIfNeitherIsAvailable = 'indent', ---@type string|fun(bufnr: number): string
      },
      pauseFoldsOnSearch = true,
      foldtext = {
        enabled = true,
        padding = 3,
        lineCount = {
          template = '%d lines', -- `%d` is replaced with the number of folded lines
          hlgroup = 'Comment',
        },
        diagnosticsCount = true, -- uses hlgroups and icons from `vim.diagnostic.config().signs`
        gitsignsCount = true, -- requires `gitsigns.nvim`
        disableOnFt = { 'snacks_picker_input' }, ---@type string[]
      },
      autoFold = {
        enabled = true,
        kinds = { 'comment', 'imports' }, ---@type lsp.FoldingRangeKind[]
      },
      foldKeymaps = {
        setup = true, -- modifies `h`, `l`, and `$`
        hOnlyOpensOnFirstColumn = false,
      },
    })

    map('n', '<Left>', function() require('origami').h() end, {
      desc = 'Origami: fold a line when used on the first non-blank character (or before)',
    })
    map('n', '<Right>', function() require('origami').l() end, {
      desc = 'Origami: unfolds the cursorline when used on a folded line',
    })
    map('n', '<End>', function() require('origami').dollar() end, {
      desc = 'Origami: unfolds the cursorline recursively when used on a folded line',
    })
  end,
}
