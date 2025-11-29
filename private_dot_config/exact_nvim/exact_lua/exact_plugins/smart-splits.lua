return {
  'mrjones2014/smart-splits.nvim',
  lazy = false,
  -- TODO: define specific build depending on terminal
  -- build = './kitty/install-kittens.bash',
  config = function()
    require('smart-splits').setup({
      -- Ignored buffer types (only while resizing)
      ignored_buftypes = {
        'nofile',
        'quickfix',
        'prompt',
      },
      -- Ignored filetypes (only while resizing)
      ignored_filetypes = { 'yazi' },
      -- the default number of lines/columns to resize by at a time
      default_amount = 3,
      at_edge = 'wrap',
      -- Desired behavior when the current window is floating:
      -- 'previous' => Focus previous Vim window and perform action
      -- 'mux' => Always forward action to multiplexer
      float_win_behavior = 'previous',
      -- when moving cursor between splits left or right,
      -- place the cursor on the same row of the *screen*
      -- regardless of line numbers. False by default.
      -- Can be overridden via function parameter, see Usage.
      move_cursor_same_row = false,
      -- whether the cursor should follow the buffer when swapping
      -- buffers by default; it can also be controlled by passing
      -- `{ move_cursor = true }` or `{ move_cursor = false }`
      -- when calling the Lua function.
      cursor_follows_swapped_bufs = false,
      -- ignore these autocmd events (via :h eventignore) while processing
      -- smart-splits.nvim computations, which involve visiting different
      -- buffers and windows. These events will be ignored during processing,
      -- and un-ignored on completed. This only applies to resize events,
      -- not cursor movement events.
      ignored_events = {
        'BufEnter',
        'WinEnter',
      },
      -- enable or disable a multiplexer integration;
      -- automatically determined, unless explicitly disabled or set,
      -- by checking the $TERM_PROGRAM environment variable,
      -- and the $KITTY_LISTEN_ON environment variable for Kitty.
      -- You can also set this value by setting `vim.g.smart_splits_multiplexer_integration`
      -- before the plugin is loaded (e.g. for lazy environments).
      -- multiplexer_integration = nil,
      -- disable multiplexer navigation if current multiplexer pane is zoomed
      -- NOTE: This does not work on Zellij as there is no way to determine the
      -- pane zoom state outside of the Zellij Plugin API, which does not apply here
      disable_multiplexer_nav_when_zoomed = true,
      -- Supply a Kitty remote control password if needed,
      -- or you can also set vim.g.smart_splits_kitty_password
      -- see https://sw.kovidgoyal.net/kitty/conf/#opt-kitty.remote_control_password
      -- kitty_password = nil,
      -- In Zellij, set this to true if you would like to move to the next *tab*
      -- when the current pane is at the edge of the zellij tab/window
      -- zellij_move_focus_or_tab = false,
      -- default logging level, one of: 'trace'|'debug'|'info'|'warn'|'error'|'fatal'
      log_level = 'info',
    })
  end,
}
