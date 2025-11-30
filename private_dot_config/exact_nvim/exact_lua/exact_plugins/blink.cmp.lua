-- reference: https://github.com/linkarzu/dotfiles-latest/blob/main/neovim/neobean/lua/plugins/blink-cmp.lua

local trigger_text = ';'

---@module 'lazy'
---@type LazySpec
return {
  'saghen/blink.cmp',
  event = 'InsertEnter',
  build = 'cargo +nightly build --release',
  -- In case there are breaking changes and you want to go back to the last
  -- working release
  -- https://github.com/Saghen/blink.cmp/releases
  -- version = "v0.13.1",
  dependencies = {
    'moyiz/blink-emoji.nvim',
    'ribru17/blink-cmp-spell',
    'mikavilpas/blink-ripgrep.nvim',
    'archie-judd/blink-cmp-words',
  },
  opts = function(_, opts)
    -- I noticed that telescope was extremely slow and taking too long to open,
    -- assumed related to blink, so disabled blink and in fact it was related
    -- :lua print(vim.bo[0].filetype)
    -- So I'm disabling blink.cmp for Telescope
    opts.enabled = function()
      -- Get the current buffer's filetype
      local filetype = vim.bo[0].filetype
      -- Disable for Telescope buffers
      if filetype == 'TelescopePrompt' or filetype == 'snacks_picker_input' then
        return false
      end
      return true
    end

    -- NOTE: The new way to enable LuaSnip
    -- Merge custom sources with the existing ones from lazyvim
    -- NOTE: by default lazyvim already includes the lazydev source, so not adding it here again
    opts.sources = vim.tbl_deep_extend('force', opts.sources or {}, {
      default = {
        'lsp',
        'path',
        'lazydev',
        'buffer',
        'snippets',
        'dadbod',
        'spell',
        'dictionary',
        'emoji',
      },
      providers = {
        lazydev = {
          name = 'LazyDev',
          module = 'lazydev.integrations.blink',
          -- make lazydev completions top priority (see `:h blink.cmp`)
          score_offset = 100,
        },
        lsp = {
          name = 'lsp',
          enabled = true,
          module = 'blink.cmp.sources.lsp',
          min_keyword_length = 2,
          -- When linking markdown notes, I would get snippets and text in the
          -- suggestions, I want those to show only if there are no LSP
          -- suggestions
          --
          -- Enabled fallbacks as this seems to be working now
          -- Disabling fallbacks as my snippets wouldn't show up when editing
          -- lua files
          -- fallbacks = { "snippets", "buffer" },
          score_offset = 90, -- the higher the number, the higher the priority
        },
        path = {
          name = 'Path',
          module = 'blink.cmp.sources.path',
          score_offset = 25,
          -- When typing a path, I would get snippets and text in the
          -- suggestions, I want those to show only if there are no path
          -- suggestions
          fallbacks = { 'snippets', 'buffer' },
          -- min_keyword_length = 2,
          opts = {
            trailing_slash = false,
            label_trailing_slash = true,
            get_cwd = function(context)
              return vim.fn.expand(('#%d:p:h'):format(context.bufnr))
            end,
            show_hidden_files_by_default = true,
          },
        },
        buffer = {
          name = 'Buffer',
          enabled = true,
          max_items = 3,
          module = 'blink.cmp.sources.buffer',
          min_keyword_length = 2,
          score_offset = 15, -- the higher the number, the higher the priority
        },
        snippets = {
          name = 'snippets',
          enabled = true,
          max_items = 15,
          min_keyword_length = 2,
          module = 'blink.cmp.sources.snippets',
          score_offset = 85, -- the higher the number, the higher the priority
          -- Only show snippets if I type the trigger_text characters, so
          -- to expand the "bash" snippet, if the trigger_text is ";" I have to
          should_show_items = function()
            local col = vim.api.nvim_win_get_cursor(0)[2]
            local before_cursor = vim.api.nvim_get_current_line():sub(1, col)
            -- NOTE: remember that `trigger_text` is modified at the top of the file
            return before_cursor:match(trigger_text .. '%w*$') ~= nil
          end,
          -- After accepting the completion, delete the trigger_text characters
          -- from the final inserted text
          -- Modified transform_items function based on suggestion by `synic` so
          -- that the luasnip source is not reloaded after each transformation
          -- https://github.com/linkarzu/dotfiles-latest/discussions/7#discussion-7849902
          -- NOTE: I also tried to add the ";" prefix to all of the snippets loaded from
          -- friendly-snippets in the luasnip.lua file, but I was unable to do
          -- so, so I still have to use the transform_items here
          -- This removes the ";" only for the friendly-snippets snippets
          transform_items = function(_, items)
            local line = vim.api.nvim_get_current_line()
            local col = vim.api.nvim_win_get_cursor(0)[2]
            local before_cursor = line:sub(1, col)
            local start_pos, end_pos =
              before_cursor:find(trigger_text .. '[^' .. trigger_text .. ']*$')
            if start_pos then
              for _, item in ipairs(items) do
                if not item.trigger_text_modified then
                  ---@diagnostic disable-next-line: inject-field
                  item.trigger_text_modified = true
                  item.textEdit = {
                    newText = item.insertText or item.label,
                    range = {
                      start = {
                        line = vim.fn.line('.') - 1,
                        character = start_pos - 1,
                      },
                      ['end'] = {
                        line = vim.fn.line('.') - 1,
                        character = end_pos,
                      },
                    },
                  }
                end
              end
            end
            return items
          end,
        },
        -- Example on how to configure dadbod found in the main repo
        -- https://github.com/kristijanhusak/vim-dadbod-completion
        dadbod = {
          name = 'Dadbod',
          module = 'vim_dadbod_completion.blink',
          min_keyword_length = 2,
          score_offset = 85, -- the higher the number, the higher the priority
        },
        -- https://github.com/moyiz/blink-emoji.nvim
        emoji = {
          module = 'blink-emoji',
          name = 'Emoji',
          score_offset = 93, -- the higher the number, the higher the priority
          min_keyword_length = 2,
          opts = { insert = true }, -- Insert emoji (default) or complete its name
        },
        spell = {
          name = 'Spell',
          module = 'blink-cmp-spell',
          opts = {
            -- EXAMPLE: Only enable source in `@spell` captures, and disable it
            -- in `@nospell` captures.
            enable_in_context = function()
              local curpos = vim.api.nvim_win_get_cursor(0)
              local captures = vim.treesitter.get_captures_at_pos(
                0,
                curpos[1] - 1,
                curpos[2] - 1
              )
              local in_spell_capture = false
              for _, cap in ipairs(captures) do
                if cap.capture == 'spell' then
                  in_spell_capture = true
                elseif cap.capture == 'nospell' then
                  return false
                end
              end
              return in_spell_capture
            end,
          },
        },
        ripgrep = {
          module = 'blink-ripgrep',
          name = 'Ripgrep',
          -- the options below are optional, some default values are shown
          ---@module "blink-ripgrep"
          ---@type blink-ripgrep.Options
          opts = {
            -- For many options, see `rg --help` for an exact description of
            -- the values that ripgrep expects.

            -- the minimum length of the current word to start searching
            -- (if the word is shorter than this, the search will not start)
            prefix_min_len = 2,

            -- The number of lines to show around each match in the preview
            -- (documentation) window. For example, 5 means to show 5 lines
            -- before, then the match, and another 5 lines after the match.
            context_size = 5,

            -- The maximum file size of a file that ripgrep should include in
            -- its search. Useful when your project contains large files that
            -- might cause performance issues.
            -- Examples:
            -- "1024" (bytes by default), "200K", "1M", "1G", which will
            -- exclude files larger than that size.
            max_filesize = '1M',

            -- Specifies how to find the root of the project where the ripgrep
            -- search will start from. Accepts the same options as the marker
            -- given to `:h vim.fs.root()` which offers many possibilities for
            -- configuration. If none can be found, defaults to Neovim's cwd.
            --
            -- Examples:
            -- - ".git" (default)
            -- - { ".git", "package.json", ".root" }
            project_root_marker = '.git',

            -- Enable fallback to neovim cwd if project_root_marker is not
            -- found. Default: `true`, which means to use the cwd.
            project_root_fallback = true,

            -- The casing to use for the search in a format that ripgrep
            -- accepts. Defaults to "--ignore-case". See `rg --help` for all the
            -- available options ripgrep supports, but you can try
            -- "--case-sensitive" or "--smart-case".
            search_casing = '--ignore-case',

            -- (advanced) Any additional options you want to give to ripgrep.
            -- See `rg -h` for a list of all available options. Might be
            -- helpful in adjusting performance in specific situations.
            -- If you have an idea for a default, please open an issue!
            --
            -- Not everything will work (obviously).
            additional_rg_options = {},

            -- When a result is found for a file whose filetype does not have a
            -- treesitter parser installed, fall back to regex based highlighting
            -- that is bundled in Neovim.
            fallback_to_regex_highlighting = true,

            -- Absolute root paths where the rg command will not be executed.
            -- Usually you want to exclude paths using gitignore files or
            -- ripgrep specific ignore files, but this can be used to only
            -- ignore the paths in blink-ripgrep.nvim, maintaining the ability
            -- to use ripgrep for those paths on the command line. If you need
            -- to find out where the searches are executed, enable `debug` and
            -- look at `:messages`.
            ignore_paths = {},

            -- Any additional paths to search in, in addition to the project
            -- root. This can be useful if you want to include dictionary files
            -- (/usr/share/dict/words), framework documentation, or any other
            -- reference material that is not available within the project
            -- root.
            additional_paths = {},

            -- Keymaps to toggle features on/off. This can be used to alter
            -- the behavior of the plugin without restarting Neovim. Nothing
            -- is enabled by default. Requires folke/snacks.nvim.
            toggles = {
              -- The keymap to toggle the plugin on and off from blink
              -- completion results. Example: "<leader>tg" ("toggle grep")
              on_off = nil,

              -- The keymap to toggle debug mode on/off. Example: "<leader>td" ("toggle debug")
              debug = nil,
            },

            -- Features that are not yet stable and might change in the future.
            -- You can enable these to try them out beforehand, but be aware
            -- that they might change. Nothing is enabled by default.
            future_features = {
              backend = {
                -- The backend to use for searching. Defaults to "ripgrep".
                -- Available options:
                -- - "ripgrep", always use ripgrep
                -- - "gitgrep", always use git grep
                -- - "gitgrep-or-ripgrep", use git grep if possible, otherwise
                --   ripgrep
                use = 'ripgrep',
              },
            },

            -- Show debug information in `:messages` that can help in
            -- diagnosing issues with the plugin.
            debug = false,
          },
          -- (optional) customize how the results are displayed. Many options
          -- are available - make sure your lua LSP is set up so you get
          -- autocompletion help
          transform_items = function(_, items)
            for _, item in ipairs(items) do
              -- example: append a description to easily distinguish rg results
              item.labelDetails = {
                description = '(rg)',
              }
            end
            return items
          end,
        },
        -- Use the thesaurus source
        thesaurus = {
          name = 'blink-cmp-words',
          module = 'blink-cmp-words.thesaurus',
          -- All available options
          opts = {
            -- A score offset applied to returned items.
            -- By default the highest score is 0 (item 1 has a score of -1, item 2 of -2 etc..).
            score_offset = 0,

            -- Default pointers define the lexical relations listed under each definition,
            -- see Pointer Symbols below.
            -- Default is as below ("antonyms", "similar to" and "also see").
            definition_pointers = { '!', '&', '^' },

            -- The pointers that are considered similar words when using the thesaurus,
            -- see Pointer Symbols below.
            -- Default is as below ("similar to", "also see" }
            similarity_pointers = { '&', '^' },

            -- The depth of similar words to recurse when collecting synonyms. 1 is similar words,
            -- 2 is similar words of similar words, etc. Increasing this may slow results.
            similarity_depth = 2,
          },
        },
        -- Use the dictionary source
        dictionary = {
          name = 'blink-cmp-words',
          module = 'blink-cmp-words.dictionary',
          -- All available options
          opts = {
            -- The number of characters required to trigger completion.
            -- Set this higher if completion is slow, 3 is default.
            dictionary_search_threshold = 3,

            -- See above
            score_offset = 0,

            -- See above
            definition_pointers = { '!', '&', '^' },
          },
        },
      },
    })

    opts.cmdline = {
      enabled = true,
    }

    opts.completion = {
      accept = {
        auto_brackets = {
          enabled = true,
          -- default_brackets = { ";", "" },
          -- override_brackets_for_filetypes = {
          --   markdown = { ";", "" },
          -- },
        },
      },
      --   keyword = {
      --     -- 'prefix' will fuzzy match on the text before the cursor
      --     -- 'full' will fuzzy match on the text before *and* after the cursor
      --     -- example: 'foo_|_bar' will match 'foo_' for 'prefix' and 'foo__bar' for 'full'
      --     range = "full",
      --   },
      menu = {
        border = 'single',
      },
      documentation = {
        auto_show = true,
        window = {
          border = 'single',
        },
      },
    }

    opts.fuzzy = {
      implementation = 'prefer_rust_with_warning',
      -- Frecency tracks the most recently/frequently used items and boosts the score of the item
      frecency = {
        enabled = true,
        path = vim.fn.stdpath('state') .. '/blink/cmp/frecency.dat',
      },
      -- Proximity bonus boosts the score of items matching nearby words
      use_proximity = false,
      sorts = {
        function(a, b)
          local sort = require('blink.cmp.fuzzy.sort')
          if a.source_id == 'spell' and b.source_id == 'spell' then
            return sort.label(a, b)
          end
        end,
        -- This is the normal default order, which we fall back to
        'score',
        'kind',
        'label',
      },
    }

    opts.snippets = {
      preset = 'luasnip', -- Choose LuaSnip as the snippet engine
    }

    -- -- To specify the options for snippets
    -- opts.sources.providers.snippets.opts = {
    --   use_show_condition = true, -- Enable filtering of snippets dynamically
    --   show_autosnippets = true, -- Display autosnippets in the completion menu
    -- }

    -- The default preset used by lazyvim accepts completions with enter
    -- I don't like using enter because if on markdown and typing
    -- something, but you want to go to the line below, if you press enter,
    -- the completion will be accepted
    -- https://cmp.saghen.dev/configuration/keymap.html#default
    opts.keymap = {
      preset = 'default',
      ['<Tab>'] = { 'snippet_forward', 'fallback' },
      ['<S-Tab>'] = { 'snippet_backward', 'fallback' },

      ['<Up>'] = { 'select_prev', 'fallback' },
      ['<Down>'] = { 'select_next', 'fallback' },
      ['<C-p>'] = { 'select_prev', 'fallback' },
      ['<C-n>'] = { 'select_next', 'fallback' },

      ['<S-k>'] = { 'scroll_documentation_up', 'fallback' },
      ['<S-j>'] = { 'scroll_documentation_down', 'fallback' },

      ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
      ['<C-e>'] = { 'hide', 'fallback' },
    }

    return opts
  end,
}
