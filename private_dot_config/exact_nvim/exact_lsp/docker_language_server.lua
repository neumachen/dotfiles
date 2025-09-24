local Lsp = require('utils.lsp')
-- mise install -g github:docker/docker-language-server
return {
  cmd = { 'docker-language-server', 'start', '--stdio' },
  on_attach = Lsp.on_attach,
  filetypes = { 'dockerfile', 'yaml.docker-compose' },
  root_markers = {
    'Dockerfile',
    'docker-compose.yaml',
    'docker-compose.yml',
    'compose.yaml',
    'compose.yml',
    'docker-bake.json',
    'docker-bake.hcl',
    'docker-bake.override.json',
    'docker-bake.override.hcl',
  },
}
