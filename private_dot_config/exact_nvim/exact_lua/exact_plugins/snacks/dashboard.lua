return {
  preset = {
    keys = {
      { icon = ' ', key = 'G', desc = 'Neogit', action = ':Neogit' },
      {
        icon = ' ',
        key = 'y',
        desc = 'Open Yazi',
        action = function() vim.cmd('Yazi cwd') end,
      },
      {
        icon = ' ',
        key = 'f',
        desc = 'Find File',
        action = ":lua Snacks.dashboard.pick('files')",
      },
      {
        icon = ' ',
        key = 'n',
        desc = 'New File',
        action = ':ene | startinsert',
      },
      {
        icon = ' ',
        key = 'g',
        desc = 'Find Text',
        action = ":lua Snacks.dashboard.pick('live_grep')",
      },
      {
        icon = ' ',
        key = 'r',
        desc = 'Recent Files',
        action = ":lua Snacks.dashboard.pick('oldfiles')",
      },
      {
        icon = ' ',
        key = 'c',
        desc = 'Config',
        action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
      },
      {
        icon = ' ',
        key = 's',
        desc = 'Restore Session',
        section = 'session',
      },
      {
        icon = '󰒲 ',
        key = 'L',
        desc = 'Lazy',
        action = ':Lazy',
        enabled = package.loaded.lazy ~= nil,
      },
      { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
    },
  },
  sections = function()
    local s = {
      { section = 'header' },
      {
        section = 'keys',
        gap = 1,
        padding = 1,
      },
      {
        pane = 2,
        icon = ' ',
        title = 'Recent Files',
        section = 'recent_files',
        indent = 2,
        padding = 1,
      },
      {
        pane = 2,
        icon = ' ',
        title = 'Git Status',
        section = 'terminal',
        enabled = function() return Snacks.git.get_root() ~= nil end,
        cmd = 'git status --short --branch --renames',
        height = 5,
        padding = 1,
        ttl = 5 * 60,
        indent = 3,
      },
      { section = 'startup' },
    }
    table.insert(s, 2, function()
      local lines = vim.fn.systemlist('fortune -s | cowsay')
      if vim.v.shell_error ~= 0 or #lines == 0 then return end
      return {
        pane = 2,
        indent = 8,
        padding = 1,
        text = vim.tbl_map(function(l)
          return { l .. '\n', hl = 'SnacksDashboardFooter' }
        end, lines),
      }
    end)
    return s
  end,
}
