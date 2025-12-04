vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.slim',
  callback = function(args)
    -- Use Slim filetype for .slim files
    vim.bo[args.buf].filetype = 'slim'
  end,
})
