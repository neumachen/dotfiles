return {
  'windwp/nvim-autopairs',
  event = 'InsertEnter',
  config = function()
    require('nvim-autopairs').setup({
      close_triple_quotes = true,
      disable_filetype = { 'TelescopePrompt', 'spectre_panel', 'snacks_picker_input' },
      check_ts = true,
      fast_wrap = { map = '<c-e>' },
      ts_config = {
        lua = { 'string' },
        javascript = { 'template_string' },
      },
    })
  end,
}
