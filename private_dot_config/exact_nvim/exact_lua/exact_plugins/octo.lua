return {
  'pwntester/octo.nvim',
  cmd = 'Octo',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'ibhagwan/fzf-lua',
    'nvim-tree/nvim-web-devicons',
  },
  keys = {
    { '<leader>goi', '<CMD>Octo issue list<CR>', desc = 'List issues' },
    { '<leader>gop', '<CMD>Octo pr list<CR>', desc = 'List pull requests' },
    { '<leader>god', '<CMD>Octo discussion list<CR>', desc = 'List discussions' },
    { '<leader>gon', '<CMD>Octo notification list<CR>', desc = 'List notifications' },
    { '<leader>gor', '<CMD>Octo repo list<CR>', desc = 'List repos' },
    {
      '<leader>gos',
      function() require('octo.utils').create_base_search_command({ include_current_repo = true }) end,
      desc = 'Search GitHub',
    },
  },
  config = function()
    require('octo').setup({
      picker = 'fzf-lua',
      picker_config = {
        use_emojis = true,
        search_static = true,
      },
      enable_builtin = true,
      suppress_missing_scope = {
        projects_v2 = true,
      },
      reviews = {
        auto_show_threads = true,
        focus = 'right',
      },
    })

    -- Register octo buffers as markdown for treesitter
    vim.treesitter.language.register('markdown', 'octo')
  end,
}
