return {
  cmd = { 'elixir-ls' },
  filetypes = { 'elixir', 'eelixir', 'heex' },
  root_markers = { 'mix.exs', '.git' },
  settings = {
    elixirLS = {
      dialyzerEnabled = true,
      fetchDeps = false,
      enableTestLenses = false,
      suggestSpecs = true,
    },
  },
}
