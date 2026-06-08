-- terraform-ls — Terraform language server from HashiCorp.
--
-- Installed via mise (`terraform-ls = "latest"` in
-- exact_mise/exact_conf.d/10-registry.toml), so `terraform-ls` is on $PATH
-- after `mise install`.
--
-- Auto-discovered by init.lua, which scans this directory for *.lua and
-- calls `vim.lsp.enable` on every basename (Neovim 0.11+ LSP loader).
-- No further wiring is needed.
--
-- Filetypes:
--   terraform        --  *.tf
--   terraform-vars   --  *.tfvars
--   hcl              --  generic HCL (Packer, Waypoint, Nomad, Boundary, ...)
--                       terraform-ls handles *.tf-flavoured HCL; pure-HCL
--                       files outside Terraform get only syntax/folding
--                       support, which is still useful.
--
-- Root markers (mirrors helm_ls/marksman style in this directory):
--   *.tf              --  presence of any tf file marks the module root
--   .terraform.lock.hcl
--   .terraform/       --  initialized module
--   .git              --  fallback so single-file editing still works
return {
  cmd = { 'terraform-ls', 'serve' },
  filetypes = { 'terraform', 'terraform-vars', 'hcl' },
  root_markers = {
    '.terraform.lock.hcl',
    '.terraform',
    'main.tf',
    'versions.tf',
    '.git',
  },
}
