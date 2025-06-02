return {
  'luukvbaal/statuscol.nvim',
  event = 'VeryLazy',
  opts = function()
    local builtin = require('statuscol.builtin')
    return {
      ft_ignore = { 'lazy', 'mason', 'snacks_dashboard' },
      segments = {
        { text = { builtin.foldfunc }, click = 'v:lua.ScLa' },
        {
          sign = { name = { 'Diagnostic*' }, text = { '.*' }, maxwidth = 3, colwidth = 3, auto = true },
          click = 'v:lua.ScSa',
        },
        { text = { builtin.foldfunc, ' ' }, click = 'v:lua.ScFa' },
      },
    }
  end,
  config = function(_, opts) require('statuscol').setup(opts) end,
}
