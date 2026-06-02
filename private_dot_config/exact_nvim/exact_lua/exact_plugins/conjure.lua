---@module "lazy"
---@type LazySpec
return {
  'Olical/conjure',
  -- Load when entering a supported REPL filetype
  ft = {
    'clojure',
    'fennel',
    'janet',
    'hy',
    'julia',
    'racket',
    'scheme',
    'lua',
    'lisp',
    'python',
    'rust',
    'sql',
  },
  init = function()
    -- Use tree-sitter for smarter form extraction (requires nvim-treesitter)
    vim.g['conjure#extract#tree_sitter#enabled'] = true

    -- Show evaluation results as inline virtual text
    vim.g['conjure#eval#inline_results'] = true

    -- Prefix for inline result virtual text
    vim.g['conjure#eval#inline#prefix'] = '=> '

    -- Store eval results in register "c" (default); paste with "cp
    vim.g['conjure#eval#result_register'] = 'c'

    -- Auto-connect to a running REPL on buffer load
    vim.g['conjure#client_on_load'] = true

    -- Keep the HUD (floating result window) enabled
    vim.g['conjure#log#hud#enabled'] = true

    -- HUD takes up at most 0.4 of the editor width
    vim.g['conjure#log#hud#width'] = 0.4

    -- HUD takes up at most 0.3 of the editor height
    vim.g['conjure#log#hud#height'] = 0.3

    -- Trim the log when it exceeds this many lines
    vim.g['conjure#log#trim#at'] = 200
    vim.g['conjure#log#trim#to'] = 100
  end,
}
