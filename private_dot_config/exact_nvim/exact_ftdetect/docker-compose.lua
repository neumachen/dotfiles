vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = {
    'compose.yaml',
    'compose.yml',
    'compose.*.yaml',
    'compose.*.yml',
    'docker-compose.yaml',
    'docker-compose.yml',
    'docker-compose.*.yaml',
    'docker-compose.*.yml',
  },
  callback = function(args)
    -- Use yaml.docker-compose so docker-language-server engages
    -- (see exact_lsp/docker_language_server.lua) while yamlls still
    -- treats the buffer as YAML for schema validation.
    vim.bo[args.buf].filetype = 'yaml.docker-compose'
  end,
})
