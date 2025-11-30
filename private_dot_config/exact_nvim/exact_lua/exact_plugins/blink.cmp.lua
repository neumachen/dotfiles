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
    'onsails/lspkind.nvim',
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
          score_offset = 100,
        },
        lsp = {
          name = 'lsp',
          enabled = true,
          module = 'blink.cmp.sources.lsp',
          score_offset = 90, -- the higher the number, the higher the priority
        },
        path = {
          name = 'Path',
          module = 'blink.cmp.sources.path',
          score_offset = 25,
          fallbacks = { 'snippets', 'buffer' },
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
          score_offset = 85,
          should_show_items = function()
            local col = vim.api.nvim_win_get_cursor(0)[2]
            local before_cursor = vim.api.nvim_get_current_line():sub(1, col)
            return before_cursor:match(trigger_text .. '%w*$') ~= nil
          end,
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
        dadbod = {
          name = 'Dadbod',
          module = 'vim_dadbod_completion.blink',
          min_keyword_length = 2,
          score_offset = 85, -- the higher the number, the higher the priority
        },
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
          ---@module "blink-ripgrep"
          ---@type blink-ripgrep.Options
          opts = {
            prefix_min_len = 2,
            context_size = 5,
            max_filesize = '1M',
            project_root_marker = '.git',
            project_root_fallback = true,
            search_casing = '--ignore-case',
            additional_rg_options = {},
            fallback_to_regex_highlighting = true,
            ignore_paths = {},
            additional_paths = {},
            toggles = {
              on_off = nil,
              debug = nil,
            },

            future_features = {
              backend = {
                use = 'ripgrep',
              },
            },

            debug = false,
          },
          transform_items = function(_, items)
            for _, item in ipairs(items) do
              item.labelDetails = {
                description = '(rg)',
              }
            end
            return items
          end,
        },
        thesaurus = {
          name = 'blink-cmp-words',
          module = 'blink-cmp-words.thesaurus',
          opts = {
            score_offset = 0,
            definition_pointers = { '!', '&', '^' },
            similarity_pointers = { '&', '^' },
            similarity_depth = 2,
          },
        },
        dictionary = {
          name = 'blink-cmp-words',
          module = 'blink-cmp-words.dictionary',
          opts = {
            dictionary_search_threshold = 3,
            score_offset = 0,
            definition_pointers = { '!', '&', '^' },
          },
        },
      },
    })

    opts.cmdline = {
      enabled = true,
    }

    opts.completion = {
      keyword = {
        range = 'prefix',
      },
      accept = {
        auto_brackets = {
          enabled = true,
        },
      },
      menu = {
        draw = {
          components = {
            kind_icon = {
              text = function(ctx)
                local icon = ctx.kind_icon
                if vim.tbl_contains({ 'Path' }, ctx.source_name) then
                  local dev_icon, _ =
                    require('nvim-web-devicons').get_icon(ctx.label)
                  if dev_icon then icon = dev_icon end
                else
                  icon = require('lspkind').symbolic(ctx.kind, {
                    mode = 'symbol',
                  })
                end

                return icon .. ctx.icon_gap
              end,

              -- Optionally, use the highlight groups from nvim-web-devicons
              -- You can also add the same function for `kind.highlight` if you want to
              -- keep the highlight groups in sync with the icons.
              highlight = function(ctx)
                local hl = ctx.kind_hl
                if vim.tbl_contains({ 'Path' }, ctx.source_name) then
                  local dev_icon, dev_hl =
                    require('nvim-web-devicons').get_icon(ctx.label)
                  if dev_icon then hl = dev_hl end
                end
                return hl
              end,
            },
          },
        },
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
