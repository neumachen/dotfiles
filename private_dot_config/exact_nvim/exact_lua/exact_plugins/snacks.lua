---@module "lazy"
---@type LazySpec
return {
  'folke/snacks.nvim',
  priority = 1000,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },
    dashboard = require('plugins.snacks.dashboard'),
    explorer = { enabled = true },
    indent = { enabled = true },
    input = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    picker = {
      enabled = true,
      ui_select = true,
    },
    quickfile = { enabled = true },
    scope = { enabled = true },
    scroll = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    toggle = require('plugins.snacks.toggle'),
    styles = {
      notification = {
        wo = { wrap = true },
      },
    },
  },
  keys = {
    -- Top Pickers & Explorer
    {
      '<leader><space>',
      function() Snacks.picker.smart() end,
      desc = 'Smart Find Files',
    },
    { '<leader>,', function() Snacks.picker.buffers() end, desc = 'Buffers' },
    { '<leader>/', function() Snacks.picker.grep() end, desc = 'Grep' },
    {
      '<leader>:',
      function() Snacks.picker.command_history() end,
      desc = 'Command History',
    },
    { '<leader>e', function() Snacks.explorer() end, desc = 'File Explorer' },
    -- find
    { '<leader>ff', function() Snacks.picker.files() end, desc = 'Find Files' },
    {
      '<leader>fg',
      function() Snacks.picker.git_files() end,
      desc = 'Find Git Files',
    },
    {
      '<leader>fp',
      function() Snacks.picker.projects() end,
      desc = 'Projects',
    },
    { '<leader>fr', function() Snacks.picker.recent() end, desc = 'Recent' },
    -- git
    {
      '<leader>gll',
      function() Snacks.picker.git_log_line() end,
      desc = 'Git Log Line',
    },
    {
      '<leader>glf',
      function() Snacks.picker.git_log_file() end,
      desc = 'Git Log File',
    },
    {
      '<leader>gS',
      function() Snacks.picker.git_stash() end,
      desc = 'Git Stash',
    },
    {
      '<leader>gb',
      function() Snacks.picker.git_branches() end,
      desc = 'Git Branches',
    },
    {
      '<leader>gd',
      function() Snacks.picker.git_diff() end,
      desc = 'Git Diff (Hunks)',
    },
    {
      '<leader>gs',
      function() Snacks.picker.git_status() end,
      desc = 'Git Status',
    },
    -- Grep
    {
      '<leader>sb',
      function() Snacks.picker.lines() end,
      desc = 'Buffer Lines',
    },
    {
      '<leader>sB',
      function() Snacks.picker.grep_buffers() end,
      desc = 'Grep Open Buffers',
    },
    { '<leader>sg', function() Snacks.picker.grep() end, desc = 'Grep' },
    {
      '<leader>sw',
      function() Snacks.picker.grep_word() end,
      desc = 'Visual selection or word',
      mode = { 'n', 'x' },
    },
    -- search
    {
      '<leader>s"',
      function() Snacks.picker.registers() end,
      desc = 'Registers',
    },
    {
      '<leader>s/',
      function() Snacks.picker.search_history() end,
      desc = 'Search History',
    },
    {
      '<leader>sa',
      function() Snacks.picker.autocmds() end,
      desc = 'Autocmds',
    },
    {
      '<leader>sb',
      function() Snacks.picker.lines() end,
      desc = 'Buffer Lines',
    },
    {
      '<leader>sc',
      function() Snacks.picker.command_history() end,
      desc = 'Command History',
    },
    {
      '<leader>sC',
      function() Snacks.picker.commands() end,
      desc = 'Commands',
    },
    {
      '<leader>sd',
      function() Snacks.picker.diagnostics() end,
      desc = 'Diagnostics',
    },
    {
      '<leader>sD',
      function() Snacks.picker.diagnostics_buffer() end,
      desc = 'Buffer Diagnostics',
    },
    { '<leader>sh', function() Snacks.picker.help() end, desc = 'Help Pages' },
    {
      '<leader>sH',
      function() Snacks.picker.highlights() end,
      desc = 'Highlights',
    },
    { '<leader>si', function() Snacks.picker.icons() end, desc = 'Icons' },
    { '<leader>sj', function() Snacks.picker.jumps() end, desc = 'Jumps' },
    { '<leader>sk', function() Snacks.picker.keymaps() end, desc = 'Keymaps' },
    {
      '<leader>sl',
      function() Snacks.picker.loclist() end,
      desc = 'Location List',
    },
    { '<leader>sm', function() Snacks.picker.marks() end, desc = 'Marks' },
    { '<leader>sM', function() Snacks.picker.man() end, desc = 'Man Pages' },
    {
      '<leader>sp',
      function() Snacks.picker.lazy() end,
      desc = 'Search for Plugin Spec',
    },
    {
      '<leader>sq',
      function() Snacks.picker.qflist() end,
      desc = 'Quickfix List',
    },
    { '<leader>sR', function() Snacks.picker.resume() end, desc = 'Resume' },
    {
      '<leader>su',
      function() Snacks.picker.undo() end,
      desc = 'Undo History',
    },
    {
      '<leader>uC',
      function() Snacks.picker.colorschemes() end,
      desc = 'Colorschemes',
    },
    -- LSP
    {
      'gd',
      function() snacks.picker.lsp_definitions() end,
      desc = 'goto definition',
    },
    {
      'gd',
      function() snacks.picker.lsp_declarations() end,
      desc = 'goto declaration',
    },
    {
      'gr',
      function() Snacks.picker.lsp_references() end,
      nowait = true,
      desc = 'References',
    },
    {
      'gI',
      function() Snacks.picker.lsp_implementations() end,
      desc = 'Goto Implementation',
    },
    {
      'gy',
      function() Snacks.picker.lsp_type_definitions() end,
      desc = 'Goto T[y]pe Definition',
    },
    {
      '<leader>ss',
      function() Snacks.picker.lsp_symbols() end,
      desc = 'LSP Symbols',
    },
    {
      '<leader>sS',
      function() Snacks.picker.lsp_workspace_symbols() end,
      desc = 'LSP Workspace Symbols',
    },
    -- Other
    {
      '<leader>bS',
      function() Snacks.scratch.select() end,
      desc = 'Select Scratch Buffer',
    },
    { '<leader>bd', function() Snacks.bufdelete() end, desc = 'Delete Buffer' },
    {
      '<leader>bs',
      function() Snacks.scratch() end,
      desc = 'Toggle Scratch Buffer',
    },
    {
      '<leader>fR',
      function() Snacks.rename.rename_file() end,
      desc = 'Rename File',
    },
    {
      '<leader>gB',
      function() Snacks.gitbrowse() end,
      desc = 'Git Browse',
      mode = { 'n', 'v' },
    },
    { '<leader>gg', function() Snacks.lazygit() end, desc = 'Lazygit' },
    {
      '<leader>nd',
      function() Snacks.notifier.hide() end,
      desc = 'Dismiss All Notifications',
    },
    {
      '<leader>nh',
      function() Snacks.notifier.show_history() end,
      desc = 'Notification History',
    },
    { '<leader>tZ', function() Snacks.zen.zoom() end, desc = 'Toggle Zoom' },
    { '<leader>tz', function() Snacks.zen() end, desc = 'Toggle Zen Mode' },
    { '<c-/>', function() Snacks.terminal() end, desc = 'Toggle Terminal' },
    {
      ']]',
      function() Snacks.words.jump(vim.v.count1) end,
      desc = 'Next Reference',
      mode = { 'n', 't' },
    },
    {
      '[[',
      function() Snacks.words.jump(-vim.v.count1) end,
      desc = 'Prev Reference',
      mode = { 'n', 't' },
    },
  },
  init = function()
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      callback = function()
        -- Setup some globals for debugging (lazy-loaded)
        _G.dd = function(...) Snacks.debug.inspect(...) end
        _G.bt = function() Snacks.debug.backtrace() end
        vim.print = _G.dd -- Override print to use snacks for `:=` command

        -- Create some toggle mappings
        Snacks.toggle.diagnostics():map('<leader>ud')
        Snacks.toggle.treesitter():map('<leader>uT')
        Snacks.toggle.inlay_hints():map('<leader>uh')
        Snacks.toggle.indent():map('<leader>ug')
        Snacks.toggle.dim():map('<leader>uD')
      end,
    })
  end,
}
