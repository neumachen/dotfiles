-- go install golang.org/x/tools/gopls@latest
return {
  cmd = { 'gopls' },
  filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  root_markers = { 'go.sum', 'go.mod', '.git', 'go.work' },
}
