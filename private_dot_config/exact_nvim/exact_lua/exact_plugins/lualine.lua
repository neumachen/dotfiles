return {
  'nvim-lualine/lualine.nvim',
  event = 'VeryLazy',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'yavorski/lualine-macro-recording.nvim',
  },
  init = function()
    -- disable until lualine loads
    vim.opt.laststatus = 0
  end,
  config = function()
    require('lualine').setup({
      options = {
        theme = 'auto',
        icons_enabled = true,
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },
        disabled_filetypes = {
          statusline = {},
          winbar = {},
        },
        ignore_focus = {},
        always_divide_middle = true,
        always_show_tabline = true,
        globalstatus = false,
        refresh = {
          statusline = 100,
          tabline = 100,
          winbar = 100,
        },
      },
      sections = {
        lualine_a = { 'mode', { 'macro_recording', '%S' } },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = {
          {
            'filename',
            file_status = true,
            newfile_status = true,
            path = 4,
            symbols = {
              modified = '',
              readonly = '',
              unnamed = '',
              newfile = '',
            },
          },
        },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { 'filename' },
        lualine_x = { 'location' },
        lualine_y = {},
        lualine_z = {},
      },
      tabline = {},
      winbar = {},
      inactive_winbar = {},
      extensions = {
        'fzf',
        'lazy',
        'mason',
        'quickfix',
        'trouble',
      },
    })
  end,
}
