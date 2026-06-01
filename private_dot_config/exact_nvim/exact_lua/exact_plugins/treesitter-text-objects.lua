---@module "lazy"
---@type LazySpec
return {
  'nvim-treesitter/nvim-treesitter-textobjects',
  branch = 'main',
  init = function() vim.g.no_plugin_maps = true end,
  config = function()
    require('nvim-treesitter-textobjects').setup({
      select = {
        -- Automatically jump forward to textobj, similar to targets.vim
        lookahead = true,
        -- You can choose the select mode (default is charwise 'v')

        selection_modes = {
          ['@parameter.outer'] = 'v', -- charwise
          ['@function.outer'] = 'V', -- linewise
        },
        include_surrounding_whitespace = false,
      },
      move = {
        -- whether to set jumps in the jumplist
        set_jumps = true,
      },
    })

    -- Selects
    local select = require('nvim-treesitter-textobjects.select')
    vim.keymap.set(
      { 'x', 'o' },
      'af',
      function() select.select_textobject('@function.outer', 'textobjects') end,
      { desc = 'Around function' }
    )
    vim.keymap.set(
      { 'x', 'o' },
      'if',
      function() select.select_textobject('@function.inner', 'textobjects') end,
      { desc = 'Inner function' }
    )
    vim.keymap.set(
      { 'x', 'o' },
      'ac',
      function() select.select_textobject('@class.outer', 'textobjects') end,
      { desc = 'Around class' }
    )
    vim.keymap.set(
      { 'x', 'o' },
      'ic',
      function() select.select_textobject('@class.inner', 'textobjects') end,
      { desc = 'Inner class' }
    )
    vim.keymap.set(
      { 'x', 'o' },
      'as',
      function() select.select_textobject('@local.scope', 'locals') end,
      { desc = 'Around scope' }
    )
    vim.keymap.set(
      { 'x', 'o' },
      'il',
      function() select.select_textobject('@loop.inner', 'textobjects') end,
      { desc = 'Inner loop' }
    )
    vim.keymap.set(
      { 'x', 'o' },
      'al',
      function() select.select_textobject('@loop.outer', 'locals') end,
      { desc = 'Around loop' }
    )

    -- Swaps
    local swap = require('nvim-treesitter-textobjects.swap')
    vim.keymap.set(
      'n',
      '<leader>a',
      function() swap.swap_next('@parameter.inner') end,
      { desc = 'Swap parameter forward' }
    )
    vim.keymap.set(
      'n',
      '<leader>A',
      function() swap.swap_previous('@parameter.outer') end,
      { desc = 'Swap parameter backward' }
    )

    -- Functions
    local move = require('nvim-treesitter-textobjects.move')
    vim.keymap.set(
      { 'n', 'x', 'o' },
      ']f',
      function() move.goto_next_start('@function.outer', 'textobjects') end,
      { desc = 'Next function start' }
    )
    vim.keymap.set(
      { 'n', 'x', 'o' },
      '[f',
      function() move.goto_previous_start('@function.outer', 'textobjects') end,
      { desc = 'Previous function start' }
    )
    -- Classes
    vim.keymap.set(
      { 'n', 'x', 'o' },
      ']c',
      function() move.goto_next_start('@class.outer', 'textobjects') end,
      { desc = 'Next class start' }
    )
    vim.keymap.set(
      { 'n', 'x', 'o' },
      '[c',
      function() move.goto_previous_start('@class.outer', 'textobjects') end,
      { desc = 'Previous class start' }
    )

    -- Loops
    vim.keymap.set(
      { 'n', 'x', 'o' },
      ']l',
      function()
        move.goto_next_start({ '@loop.inner', '@loop.outer' }, 'textobjects')
      end,
      { desc = 'Next loop' }
    )
    vim.keymap.set(
      { 'n', 'x', 'o' },
      '[l',
      function()
        move.goto_previous_start(
          { '@loop.inner', '@loop.outer' },
          'textobjects'
        )
      end,
      { desc = 'Previous loop' }
    )
  end,
}
