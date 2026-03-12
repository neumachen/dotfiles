return {
  'sQVe/sort.nvim',
  config = function()
    require('sort').setup({
      delimiters = {
        ',',
        '|',
        ';',
        ':',
        's', -- Space.
        't', -- Tab.
      },
      natural_sort = true,
      ignore_case = false,
      whitespace = {
        alignment_threshold = 2,
      },
      mappings = {
        operator = 'go',
        textobject = {
          inner = 'io',
          around = 'ao',
        },
        -- NOTE: ']o'/'[o' conflicted with toggle.nvim's next/previous_option_prefix.
        motion = {
          next_delimiter = ']O',
          prev_delimiter = '[O',
        },
      },
    })
  end,
}
