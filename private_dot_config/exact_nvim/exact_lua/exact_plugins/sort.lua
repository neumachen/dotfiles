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
        alignment_threshold = 3,
      },
      mappings = {
        operator = 'go',
        textobject = {
          inner = 'io',
          around = 'ao',
        },
        motion = {
          next_delimiter = ']o',
          prev_delimiter = '[o',
        },
      },
    })
  end,
}
