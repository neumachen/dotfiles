vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.mdc',
  callback = function(args)
    -- Markdown Components (.mdc): markdown with YAML frontmatter and
    -- component/directive blocks (Cursor rules, Nuxt Content). Use the
    -- compound `markdown.mdc` filetype so the buffer stays identifiable as
    -- MDC while inheriting the full markdown tooling stack (marksman LSP,
    -- treesitter, render-markdown, conform, harper/codebook). Mirrors the
    -- existing `markdown.mdx` / `yaml.docker-compose` compound-ft pattern.
    vim.bo[args.buf].filetype = 'markdown.mdc'
  end,
})
