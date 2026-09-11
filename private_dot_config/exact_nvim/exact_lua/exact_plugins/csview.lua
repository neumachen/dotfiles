return {
  'hat0uma/csvview.nvim',
  ---@module "csvview"
  ---@type CsvView.Options
  opts = {
    parser = { comments = { '#', '//' } },
    -- Render fields with vertical border delimiters.
    -- Header detection stays automatic (header_lnum defaults to true) and the
    -- default sticky header remains enabled; we intentionally do not force the
    -- first line to be the header.
    view = { display_mode = 'border' },
    keymaps = { -- Text objects for selecting fields
      textobject_field_inner = { 'if', mode = { 'o', 'x' } },
      textobject_field_outer = { 'af', mode = { 'o', 'x' } },
      -- Excel-like navigation:
      -- Use <Tab> and <S-Tab> to move horizontally between fields.
      -- Use <Enter> and <S-Enter> to move vertically between rows and place the cursor at the end of the field.
      -- Note: In terminals, you may need to enable CSI-u mode to use <S-Tab> and <S-Enter>.
      jump_next_field_end = { '<Tab>', mode = { 'n', 'v' } },
      jump_prev_field_end = { '<S-Tab>', mode = { 'n', 'v' } },
      jump_next_row = { '<Enter>', mode = { 'n', 'v' } },
      jump_prev_row = { '<S-Enter>', mode = { 'n', 'v' } },
    },
  },
  ft = { 'csv', 'tsv' },
  cmd = { 'CsvViewEnable', 'CsvViewDisable', 'CsvViewToggle' },
  config = function(_, opts)
    local csvview = require('csvview')
    csvview.setup(opts)

    -- Auto-enable the tabular view whenever a CSV/TSV buffer is opened.
    -- Guard on is_enabled so we never double-enable (csvview warns and skips
    -- on a second enable, but this keeps subsequent openings quiet too).
    local group =
      vim.api.nvim_create_augroup('CsvViewAutoEnable', { clear = true })
    vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = { 'csv', 'tsv' },
      callback = function(args)
        if not csvview.is_enabled(args.buf) then csvview.enable(args.buf) end
      end,
    })

    -- The FileType event that lazy-loaded this plugin already fired before the
    -- autocmd above existed, so enable the current buffer explicitly to cover
    -- that first load event.
    local buf = vim.api.nvim_get_current_buf()
    local ft = vim.bo[buf].filetype
    if (ft == 'csv' or ft == 'tsv') and not csvview.is_enabled(buf) then
      csvview.enable(buf)
    end
  end,
}
