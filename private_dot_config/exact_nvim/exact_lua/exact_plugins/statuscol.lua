return {
  'luukvbaal/statuscol.nvim',
  event = 'VeryLazy',
  config = function()
    local builtin = require('statuscol.builtin')
    require('statuscol').setup({
      -- configuration goes here, for example:
      relculright = true,
      ft_ignore = { 'lazy', 'mason', 'snacks_dashboard' },
      segments = {
        { text = { builtin.foldfunc }, click = 'v:lua.ScFa' },
        {
          sign = {
            namespace = { 'diagnostic' },
            maxwidth = 1,
            colwidth = 2,
            auto = true,
            foldclosed = true,
          },
          click = 'v:lua.ScSa',
        },
        { text = { builtin.lnumfunc }, click = 'v:lua.ScLa' },
        {
          sign = {
            name = { '.*' },
            text = { '.*' },
            maxwidth = 2,
            colwidth = 1,
            auto = true,
            foldclosed = true,
          },
          click = 'v:lua.ScSa',
        },
        {
          sign = {
            namespace = { 'gitsigns' },
            fillchar = '│',
            maxwidth = 1,
            colwidth = 1,
            wrap = true,
            foldclosed = true,
          },
          click = 'v:lua.ScSa',
        },
      },
    })
  end,
}
