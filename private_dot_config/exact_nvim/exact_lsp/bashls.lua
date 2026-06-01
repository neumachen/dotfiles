-- mise: bash-language-server
return {
  cmd = { 'bash-language-server', 'start' },
  filetypes = { 'sh', 'bash' },
  root_markers = { '.git' },
  settings = {
    bashIde = { shellcheckPath = 'shellcheck' }, -- shellcheck already provisioned via mise
  },
}
