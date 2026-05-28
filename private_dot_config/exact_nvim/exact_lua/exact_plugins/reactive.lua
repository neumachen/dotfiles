return {
  'rasulomaroff/reactive.nvim',
  config = function()
    -- Skip reactive's per-mode highlight reapplication inside floating
    -- prompts whose redraw cycle visibly fights with cursor moves. The
    -- snacks picker input is the canonical offender: ModeChanged fires
    -- as the picker opens and (on some terminals) the per-mode `Cursor`
    -- highlight rewrite during a redraw causes the cursor to briefly
    -- render one column behind the freshly-typed character.
    --
    -- Reactive's `skip` is invoked on every mode change; returning true
    -- bypasses both window-local and global highlight application for
    -- that event.
    local skip_in_picker_input = function()
      return vim.bo.filetype == 'snacks_picker_input'
    end

    require('reactive').setup({
      builtin = {
        cursorline = { skip = skip_in_picker_input },
        cursor = { skip = skip_in_picker_input },
        modemsg = { skip = skip_in_picker_input },
      },
    })
  end,
}
