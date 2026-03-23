# Neovim Configuration Documentation

## Table of Contents

- [Overview](#overview)
- [Settings](#settings)
- [Keymaps](#keymaps)
- [Autocmds](#autocmds)
- [Plugins](#plugins)
  - [Core / Libraries](#core--libraries)
  - [LSP](#lsp)
  - [Completion](#completion)
  - [Treesitter](#treesitter)
  - [Formatting & Linting](#formatting--linting)
  - [Git](#git)
  - [UI & Appearance](#ui--appearance)
  - [Navigation & Motion](#navigation--motion)
  - [Editing](#editing)
  - [File Management](#file-management)
  - [Search](#search)
  - [Notes & Writing](#notes--writing)
  - [Database](#database)
  - [REST / HTTP](#rest--http)
  - [Diagnostics & Code Actions](#diagnostics--code-actions)
  - [Session & Project](#session--project)
  - [Miscellaneous](#miscellaneous)
- [LSP Servers](#lsp-servers)
- [Local Plugins (plugin/)](#local-plugins-plugin)
- [Utility Modules (lua/utils/)](#utility-modules-luautils)

---

## Overview

Entry point: `init.lua`

1. Loads `config.settings`
2. Loads optional `.nvim-config.lua` from the current working directory (project-local settings, git-ignored)
3. Loads `config.autocmds`, `config.lazy`, `config.keymaps`
4. If not in VSCode, sets the colorscheme (`tokyonight-storm`) and enables all LSP servers discovered from the `lsp/` directory
5. The TypeScript LSP server is selected via `vim.g.lsp_typescript_server` (default: `"ts_ls"`; alternative: `"vtsls"`)
6. Additional LSP servers can be enabled on-demand via `vim.g.lsp_on_demands = { "eslint", ... }`
7. Extra plugins can be enabled via `vim.g.enable_extra_plugins = { "no-neck-pain", ... }` (loaded from `lua/plugins/extra/`)

---

## Settings

File: `lua/config/settings.lua`

### Leader Keys

| Variable | Value | Description |
|---|---|---|
| `mapleader` | `,` | Global leader key |
| `maplocalleader` | `<Space>` | Local leader key |

### Disabled Providers

Ruby, Perl, Node, and Python3 providers are all disabled (`vim.g.loaded_*_provider = 0`).

### Key Options

| Option | Value | Notes |
|---|---|---|
| `clipboard` | `unnamedplus` | Disabled in SSH sessions |
| `updatetime` | `200` | |
| `timeoutlen` | `300` (non-VSCode) | |
| `splitbelow` | `true` | |
| `splitright` | `true` | |
| `foldmethod` | `expr` | Uses `vim.treesitter.foldexpr()` |
| `foldlevel` | `99` | |
| `grepprg` | `rg` | ripgrep with vimgrep format |
| `number` | `true` | |
| `relativenumber` | `true` | |
| `expandtab` | `true` | Spaces, not tabs |
| `shiftwidth` | `2` | |
| `textwidth` | `80` | |
| `scrolloff` | `9` | |
| `ignorecase` | `true` | |
| `smartcase` | `true` | |
| `undofile` | `true` | |
| `undolevels` | `10000` | |
| `conceallevel` | `2` | |
| `signcolumn` | `yes:1` | |
| `cmdheight` | `0` | |
| `laststatus` | `3` | Global statusline |
| `completeopt` | `menu,menuone,noselect,fuzzy` | |
| `spelllang` | `en` | |
| `spelloptions` | `camel,noplainbuffer` | |

### Diagnostic Signs

| Severity | Icon |
|---|---|
| Error | ` ` |
| Warn | ` ` |
| Hint | ` ` |
| Info | ` ` |

Virtual text is enabled with `spacing=4`, `source=if_many`, `prefix=●`.

### Neovide-specific

When `vim.g.neovide` is set:
- `neovide_hide_mouse_when_typing = true`
- `neovide_cursor_antialiasing = false`
- `neovide_input_macos_option_key_is_meta = "only_left"`

---

## Keymaps

File: `lua/config/keymaps.lua`

### General

| Mode | Key | Action |
|---|---|---|
| n/v | `<localleader>;` | Command line (`:`) |
| n/v | `<localleader><localleader>;` | Replay recent command (`@:`) |
| n/x | `j` / `<Down>` | Smart down (`gj` when no count) |
| n/x | `k` / `<Up>` | Smart up (`gk` when no count) |
| i | `jk` | Exit insert mode |
| n/i/v/x/s | `<C-s>` | Save file (with notifications; guards for terminal, readonly, special buffers) |
| n | `<leader>K` | Keywordprg |
| n | `<leader>qq` | Quit all |
| n | `<leader>ui` | Inspect pos |
| n | `<leader>uI` | Inspect tree |
| n | `<leader>zz` | Open Lazy |
| n | `<leader>fn` | New file |

### Navigation

| Mode | Key | Action |
|---|---|---|
| n | `gl` | Go to end of line (`$`) |
| n | `gh` | Go to start of line (`^`) |
| n | `<A-h>` | Go to start of line (`^`) |
| n | `<A-l>` | Go to end of line (`$`) |
| n | `<A-a>` | Select all |
| n | `<S-h>` / `[b` | Previous buffer |
| n | `<S-l>` / `]b` | Next buffer |
| n | `<leader>bb` / `<leader>\`` | Switch to other buffer |

### Moving Lines

| Mode | Key | Action |
|---|---|---|
| n | `<C-A-j>` / `<C-A-k>` | Move line down/up |
| i | `<C-A-j>` / `<C-A-k>` | Move line down/up |
| v | `<C-A-j>` / `<C-A-k>` | Move block down/up |

### Search

| Mode | Key | Action |
|---|---|---|
| i/n | `<esc>` | Clear hlsearch |
| n | `<leader>ur` | Redraw / clear hlsearch / diff update |
| n/x/o | `n` | Next result (saner behavior) |
| n/x/o | `N` | Prev result (saner behavior) |

### Windows & Tabs

| Mode | Key | Action |
|---|---|---|
| n | `<leader>ww` | Other window |
| n | `<leader>wd` | Delete window |
| n | `<leader>w-` / `<leader>-` | Split below |
| n | `<leader>w\|` / `<leader>\|` | Split right |
| n | `<leader><tab><tab>` | New tab |
| n | `<leader><tab>d` | Close tab |
| n | `<leader><tab>]` / `<leader><tab>[` | Next/prev tab |
| n | `<leader><tab>l` / `<leader><tab>f` | Last/first tab |
| n | `<leader><tab>o` | Close other tabs |

### Terminal

| Mode | Key | Action |
|---|---|---|
| t | `<esc><esc>` | Enter normal mode |
| t | `<C-h/j/k/l>` | Navigate windows |
| t | `<C-/>` | Hide terminal |

### Diagnostics

| Mode | Key | Action |
|---|---|---|
| n | `<leader>cd` | Line diagnostics (float) |
| n | `]d` / `[d` | Next/prev diagnostic |
| n | `]e` / `[e` | Next/prev error |
| n | `]w` / `[w` | Next/prev warning |

### Quickfix / Location List

| Mode | Key | Action |
|---|---|---|
| n | `<leader>xl` | Toggle location list |
| n | `<leader>xq` | Toggle quickfix list |
| n | `[q` / `]q` | Prev/next quickfix |

### Folding

| Mode | Key | Action |
|---|---|---|
| n | `zv` | Close all folds except current |
| n | `zj` | Close current, open next fold |
| n | `zk` | Close current, open prev fold |
| n | `<space><space>` | Toggle fold under cursor |
| n | `<localleader>z` | Center viewport (refocus folds) |
| n | `zO` | Recursively open top-level fold |

### Visual Mode

| Mode | Key | Action |
|---|---|---|
| v | `p` | Paste without overwriting yank register |
| v | `<` / `>` | Indent and stay in visual mode |
| n | `<C-c>` | Copy whole file to clipboard |

### Spelling

| Mode | Key | Action |
|---|---|---|
| n | `z0` | Fix word under cursor (first suggestion) |
| n | `<leader>uS` | Add unknown word to cspell dictionary |

### Autoformat Toggle

| Mode | Key | Action |
|---|---|---|
| n | `<leader>uf` | Toggle autoformat on save |

User commands `FormatDisable[!]` and `FormatEnable` are also defined.

### Replace Selected Characters

| Mode | Key | Action |
|---|---|---|
| v | `<localleader>rc` | Replace selected character(s) across buffer |

### Neovide (macOS)

| Mode | Key | Action |
|---|---|---|
| n | `<D-s>` | Save |
| v | `<D-c>` | Copy |
| n/v | `<D-v>` | Paste |
| i/c | `<D-v>` | Paste |
| t | `<D-v>` | Paste |

---

## Autocmds

File: `lua/config/autocmds.lua`

| Event | Description |
|---|---|
| `FocusGained`, `TermClose`, `TermLeave` | `checktime` — reload if file changed externally |
| `TextYankPost` | Highlight yanked text |
| `VimResized` | Equalize splits |
| `BufReadPost` | Restore last cursor position |
| `FileType` (various) | Close with `q` (help, qf, notify, etc.) |
| `FileType man` | Mark as unlisted |
| `FileType` (text/tex/typ/gitcommit/markdown) | Enable wrap + spell |
| `FileType` (json/jsonc/json5) | Set `conceallevel=0` |
| `BufWritePre` | Auto-create intermediate directories |
| `BufRead/BufNewFile *.env, .env.*` | Set filetype to `sh` |
| `BufRead/BufNewFile *.hurl` | Set filetype to `hurl` |
| `BufRead/BufNewFile *.tomg-config*` | Set filetype to `toml` |
| `BufRead/BufNewFile *.ejs, *.ejs.t` | Set filetype to `embedded_template` |
| `BufRead/BufNewFile *.code-snippets` | Set filetype to `json` |
| `BufRead/BufNewFile $DOTFILES_DIR/*` | Auto-apply chezmoi on save |
| `LspAttach` | Enable native completion (if `completion_mode=native`) and disable inlay hints by default |

---

## Plugins

### Core / Libraries

#### `nvim-lua/plenary.nvim`
General-purpose Lua library. Used as a dependency by many plugins.

#### `nvim-tree/nvim-web-devicons`
File type icons.

#### `echasnovski/mini.icons`
Alternative icon provider.

#### `neovim/nvim-lspconfig`
LSP configuration framework (used for type annotations; actual LSP enabling is done via `vim.lsp.enable()` in Neovim 0.11+).

#### `folke/lazydev.nvim`
Provides Lua LSP completions and type hints for Neovim's own APIs and plugin development. Integrates with `wezterm-types` for WezTerm config files.

**Dependencies:** `DrKJeff16/wezterm-types`

---

### LSP

#### `saghen/blink.cmp`
Fast, async completion engine written in Rust.

**File:** `lua/plugins/blink.cmp.lua`

**Trigger:** `InsertEnter`  
**Build:** `cargo +nightly build --release`

**Sources (in priority order):**

| Source | Module | Notes |
|---|---|---|
| `lsp` | `blink.cmp.sources.lsp` | Score offset 90 |
| `lazydev` | `lazydev.integrations.blink` | Score offset 100 |
| `snippets` | `blink.cmp.sources.snippets` | Triggered by `;` prefix |
| `dadbod` | `vim_dadbod_completion.blink` | DB completion |
| `emoji` | `blink-emoji` | Score offset 93 |
| `spell` | `blink-cmp-spell` | Only in treesitter `@spell` captures |
| `ripgrep` | `blink-ripgrep` | Project-wide word completion |
| `dictionary` | `blink-cmp-words.dictionary` | |
| `thesaurus` | `blink-cmp-words.thesaurus` | |
| `path` | `blink.cmp.sources.path` | Score offset 25 |
| `buffer` | `blink.cmp.sources.buffer` | Score offset 15 |

**Keymaps:**

| Key | Action |
|---|---|
| `<Tab>` / `<S-Tab>` | Snippet forward/backward |
| `<Up>` / `<C-p>` | Select previous |
| `<Down>` / `<C-n>` | Select next |
| `<S-k>` / `<S-j>` | Scroll documentation up/down |
| `<C-space>` | Show/hide documentation |
| `<C-e>` | Hide completion |

**Snippet engine:** LuaSnip  
**Disabled for:** `TelescopePrompt`, `snacks_picker_input`

**Dependencies:** `blink-emoji.nvim`, `blink-cmp-spell`, `blink-ripgrep.nvim`, `blink-cmp-words`, `lspkind.nvim`

---

#### `L3MON4D3/LuaSnip`

**File:** `lua/plugins/luasnip.lua`

Snippet engine with support for autosnippets and choice/insert nodes.

**Trigger:** `InsertEnter`  
**Build:** `make install_jsregexp`  
**Dependencies:** `rafamadriz/friendly-snippets`

---

### Treesitter

#### `nvim-treesitter/nvim-treesitter`

**File:** `lua/plugins/nvim-treesitter.lua`

Auto-installs parsers on `FileType`. Parsers are batch-installed after `LazyDone`. Buffers waiting for parser installation are queued and re-enabled after install.

**Custom predicate:** `is-mise?` — matches `*mise*.toml` filenames (used in queries).

**Installed parsers:** bash, c, cmake, cpp, css, csv, diff, dockerfile, editorconfig, elixir, erlang, git_config, git_rebase, gitcommit, gleam, go, goctl, gomod, gosum, gotmpl, gowork, gpg, haskell, helm, html, hurl, javascript, jsdoc, json, jsonc, just, lua, luadoc, luap, markdown, markdown_inline, printf, proto, python, query, regex, ruby, rust, slim, ssh_config, toml, tsx, typescript, vim, vimdoc, xml, yaml.

**Dependencies:** `nvim-treesitter-context` (max 4 lines, multiline threshold 2)

#### `nvim-treesitter/nvim-treesitter-textobjects`

**File:** `lua/plugins/treesitter-text-objects.lua`

**Text object selects (`x`/`o` mode):**

| Key | Object |
|---|---|
| `af` / `if` | Function outer/inner |
| `ac` / `ic` | Class outer/inner |
| `as` | Scope (locals) |
| `al` / `il` | Loop outer/inner |

**Swaps (`n` mode):**

| Key | Action |
|---|---|
| `<leader>a` | Swap next parameter |
| `<leader>A` | Swap previous parameter |

**Moves (`n`/`x`/`o` mode):**

| Key | Action |
|---|---|
| `]f` / `[f` | Next/prev function start |
| `]c` / `[c` | Next/prev class start |
| `]l` / `[l` | Next/prev loop start |

#### `JoosepAlviste/nvim-ts-context-commentstring`
Sets correct comment string based on treesitter context (useful in embedded languages).

#### `windwp/nvim-ts-autotag`
Auto-close and rename HTML/JSX/XML tags.

**Filetypes:** astro, glimmer, handlebars, html, javascript, javascriptreact, jsx, liquid, markdown, php, rescript, svelte, tsx, twig, typescript, typescriptreact, vue, xml.

#### `HiPhish/rainbow-delimiters.nvim`
Rainbow bracket/delimiter colorization using treesitter.

---

### Formatting & Linting

#### `stevearc/conform.nvim`

**File:** `lua/plugins/conform.lua`

**Trigger:** `BufWritePre`

Format on save with LSP fallback (500ms timeout). Also runs after save with LSP fallback.

**Formatters by filetype:**

| Filetype | Formatters |
|---|---|
| `dockerfile` | `dockerfmt` |
| `lua` | `stylua` |
| `go` | `goimports`, `gofumpt` |
| `python` | `ruff_format` or `isort`+`black` |
| `ruby` | `rubocop` |
| `json` | `biome` → `dprint` (first available) |
| `markdown` | `prettierd` → `prettier` → `dprint` |
| `javascript` | `biome` → `deno_fmt` → `prettierd` → `prettier` → `dprint` |
| `javascriptreact` | `rustywind` + first of biome/deno_fmt/prettierd/prettier/dprint |
| `typescript` | `biome` → `deno_fmt` → `prettierd` → `prettier` → `dprint` |
| `typescriptreact` | `rustywind` + first available |
| `svelte` | `rustywind` + first available |
| `html` | `prettierd` → `prettier` |
| `css` / `scss` | `prettierd` → `prettier` |
| `yaml` | `prettierd` → `prettier` |
| `toml` | `taplo` |
| `sql` | `sql_formatter` → `sqlfluff` |
| `sh` / `bash` / `zsh` | `shfmt` |

**Conditional formatters:**
- `biome`: used only when `biome.json` exists and is not inside the nvim config directory
- `prettier`/`prettierd`: used when biome is absent
- `deno_fmt`: used when `deno.json`/`deno.jsonc` exists
- `dprint`: used when `dprint.json` exists

**Keymaps:**

| Key | Action |
|---|---|
| `<leader>cn` | ConformInfo |

#### `mfussenegger/nvim-lint`

**File:** `lua/plugins/nvim-lint.lua`

**Trigger:** `VeryLazy`; runs on `BufWritePost`, `BufReadPost`, `InsertLeave`.

**Linters by filetype:**

| Filetype | Linters |
|---|---|
| `go` | `golangcilint` |
| `ruby` | `rubocop` |
| `dockerfile` | `hadolint` |
| `javascript` | `oxlint`, `eslint_d` |
| `typescript` | `oxlint`, `eslint_d` |
| `javascriptreact` | `oxlint`, `eslint_d` |
| `typescriptreact` | `oxlint`, `eslint_d` |

`eslint_d` is wrapped to suppress "Could not find config file" errors.

---

### Git

#### `lewis6991/gitsigns.nvim`

**File:** `lua/plugins/gitsigns.lua`

**Trigger:** `BufReadPre`, `BufNewFile`

**Signs:**

| Type | Text |
|---|---|
| add | `┃` |
| change | `┃` |
| delete | `_` |
| topdelete | `‾` |
| changedelete | `~` |
| untracked | `┆` |

Current line blame is enabled unless in a `dotfiles` directory.  
Blame format: `<author>, <author_time:%R> - <summary>`

**Keymaps:**

| Mode | Key | Action |
|---|---|---|
| n | `<leader>ghu` | Undo stage hunk |
| n | `<leader>ghp` | Preview hunk inline |
| n | `<leader>gtb` | Toggle current line blame |
| n | `<leader>gtd` | Show deleted lines |
| n | `<leader>gtw` | Toggle word diff |
| n | `<localleader>gbs` | Stage entire buffer |
| n | `<localleader>gbR` | Reset entire buffer |
| n | `<localleader>gbl` | Blame current line |
| n | `<leader>lm` | List modified in quickfix |
| n/v | `<localleader>ghs` | Stage hunk |
| n/v | `<localleader>ghr` | Reset hunk |
| o/x | `ih` | Select hunk |
| n | `[h` / `]h` | Next/prev git hunk |

#### `NeogitOrg/neogit`

**File:** `lua/plugins/neogit.lua`

Git interface similar to Magit.

**Dependencies:** `folke/snacks.nvim`, `nvim-lua/plenary.nvim`, `sindrets/diffview.nvim`

**Keymaps:**

| Key | Action |
|---|---|
| `<leader>tN` / `<localleader>G` | Open Neogit |
| `<leader>tnc` | Open commit buffer |
| `<leader>tnp` | Open pull popup |
| `<leader>tnP` | Open push popup |

#### `sindrets/diffview.nvim`

**File:** `lua/plugins/diffview.lua`

Diff viewer and file history browser.

**Keymaps:**

| Mode | Key | Action |
|---|---|---|
| n | `<localleader>gd` | Open DiffviewOpen |
| v | `gh` | File history for selection |
| n | `<localleader>gh` | File history |

In diff windows: custom winbar showing branch, commit, and ref info.  
`q` closes the diff view in all panels.

#### `isakbm/gitgraph.nvim`

**File:** `lua/plugins/gitgraph.lua`

Visual git graph with diffview integration.

**Dependencies:** `sindrets/diffview.nvim`

**Keymaps:**

| Key | Action |
|---|---|
| `<leader>glg` | Draw git graph (all branches, max 5000) |

Selecting a commit opens `DiffviewOpen <hash>^!`.  
Selecting a range opens `DiffviewOpen <from>~1..<to>`.

#### `FabijanZulj/blame.nvim`

**File:** `lua/plugins/blame.nvim`

Git blame viewer. Options: `blame_options = { '-w' }` (ignore whitespace).

#### `esmuellert/codediff.nvim`

**File:** `lua/plugins/codediff.lua`

Side-by-side code diff viewer with conflict resolution support.

**Dependencies:** `MunifTanjim/nui.nvim`  
**Command:** `CodeDiff`

Features: explorer panel, conflict resolution keymaps, merge conflict support.

---

### UI & Appearance

#### `folke/tokyonight.nvim`

**File:** `lua/plugins/themes.lua` + `lua/plugins/themes/tokyonight.lua`

**Style:** `storm` (dark) / `day` (light)  
**Transparent:** yes  
**Terminal colors:** disabled  
**lualine_bold:** true

#### `catppuccin/nvim`

**File:** `lua/plugins/themes/catpuccin.lua`

**Flavour:** auto (latte/mocha by background)  
Dark background overrides: `base`, `mantle`, `crust` → `#2C3441`  
Custom background groups: Normal, NormalNC, NormalFloat, SignColumn, FoldColumn, StatusLine

#### `AlexvZyl/nordic.nvim`

**File:** `lua/plugins/themes/nordic.lua`

After loading: applies `#2C3441` background to standard highlight groups on dark backgrounds.

#### `rmehri01/onenord.nvim`

**File:** `lua/plugins/themes/onenord.lua`

Styles vary by dark/light background.  
Dark background override: `#2C3441`.

#### `nvim-lualine/lualine.nvim`

**File:** `lua/plugins/lualine.lua`

**Trigger:** `VeryLazy`

**Sections:**
- `lualine_a`: mode, macro recording
- `lualine_b`: branch, diff, diagnostics
- `lualine_c`: filename (full path, with modified/readonly symbols)
- `lualine_x`: active LSP clients, encoding, fileformat, filetype
- `lualine_y`: progress
- `lualine_z`: location

**Dependencies:** `nvim-web-devicons`, `lualine-macro-recording.nvim`

#### `akinsho/bufferline.nvim`

**File:** `lua/plugins/bufferline.lua`

**Trigger:** `VeryLazy`  
**Style:** thin separators, only shown when needed.

**Keymaps:**

| Key | Action |
|---|---|
| `<leader>btp` | Toggle pin |
| `<leader>btP` | Close non-pinned buffers |
| `<leader>bco` | Close other buffers |
| `<leader>bcr` / `<leader>bcl` | Close right/left buffers |
| `<leader>bp` | Pick buffer |
| `<S-h>` / `[b` | Previous buffer |
| `<S-l>` / `]b` | Next buffer |
| `[B` / `]B` | Move buffer prev/next |

#### `folke/noice.nvim`

**File:** `lua/plugins/noice.lua`

**Trigger:** `VeryLazy`  
**Dependencies:** `MunifTanjim/nui.nvim`

Replaces the command line, messages, and popup menu with custom UI.

**Features:**
- LSP hover, signature, documentation with custom position (row 2)
- Cmdline popup centered at row 5, col 50%
- Routes: skip common write/search messages; send large messages to vsplit; warnings/errors to notify
- TSC notifications are merged/replaced
- `inc_rename`, `long_message_to_split`, `lsp_doc_border` presets enabled

**Keymaps:**

| Mode | Key | Action |
|---|---|---|
| n/i/s | `<C-f>` | Scroll LSP doc down |
| n/i/s | `<C-b>` | Scroll LSP doc up |
| c | `<M-CR>` | Redirect cmdline output |

#### `folke/which-key.nvim`

**File:** `lua/plugins/which-key.lua`

**Trigger:** `VeryLazy`

Preset: `modern`. Spell suggestions enabled.

**Registered groups:**

| Prefix | Group |
|---|---|
| `<leader>b` | +buffer |
| `<leader>c` | +code (lsp) |
| `<leader>f` | +file |
| `<leader>g` | +git |
| `<leader>m` | +marker |
| `<leader>n` | +notification |
| `<leader>s` | +find/search |
| `<leader>t` | +toggle |
| `<leader>w` | +window |
| `<leader><tab>` | +tab |
| `<localleader>t` | +toggle |
| `<localleader>d` | +diagnostics |
| `<localleader>f` | +format |
| `<localleader>g` | +git |
| `<localleader>s` | +find/search |
| `<localleader>y` | +yazi |
| `<leader>gh` | +hunk |
| `<leader>gl` | +log |
| `<leader>gt` | +toggle |
| `<leader>tn` | +neogit |
| `<leader>ts` | +scooter |
| `<localleader>gb` | +buffer (git) |
| `<localleader>gh` | +hunk (git) |
| `<localleader>tn` | +Namu |

#### `folke/snacks.nvim`

**File:** `lua/plugins/snacks.lua`

**Priority:** 1000 (loads immediately)

**Enabled modules:**

| Module | Notes |
|---|---|
| `bigfile` | Disables features for large files |
| `dashboard` | Custom dashboard (see below) |
| `explorer` | File explorer |
| `indent` | Indent guides |
| `image` | Image preview |
| `input` | Better input UI |
| `notifier` | Notification system (3s timeout) |
| `picker` | Fuzzy finder (replaces Telescope; `ui_select = true`) |
| `quickfile` | Fast file opening |
| `scope` | Scope highlighting |
| `scroll` | Smooth scrolling |
| `words` | Word highlighting |
| `toggle` | Toggle utilities |

**Dashboard sections:** header, cowsay fortune (pane 2), keys, recent files (pane 2), git status (pane 2), startup.

**Dashboard keys:**

| Key | Action |
|---|---|
| `y` | Open Yazi (cwd) |
| `f` | Find file |
| `n` | New file |
| `g` | Find text (live grep) |
| `r` | Recent files |
| `c` | Config files |
| `s` | Restore session |
| `L` | Lazy |
| `q` | Quit |

**Picker keymaps (selection):**

| Key | Action |
|---|---|
| `<leader><space>` | Smart find files |
| `<leader>,` | Buffers |
| `<leader>/` | Grep |
| `<leader>:` | Command history |
| `<leader>e` | File explorer |
| `<leader>ff` | Find files |
| `<leader>fg` | Git files |
| `<leader>fp` | Projects |
| `<leader>fr` | Recent files |
| `<leader>gll` | Git log line |
| `<leader>glf` | Git log file |
| `<leader>gS` | Git stash |
| `<leader>gb` | Git branches |
| `<leader>gd` | Git diff (hunks) |
| `<leader>gs` | Git status |
| `<leader>sb` | Buffer lines |
| `<leader>sB` | Grep open buffers |
| `<leader>sg` | Grep |
| `<leader>sw` | Grep word/selection |
| `<leader>s"` | Registers |
| `<leader>s/` | Search history |
| `<leader>sa` | Autocmds |
| `<leader>sc` | Command history |
| `<leader>sC` | Commands |
| `<leader>sd` | Diagnostics |
| `<leader>sD` | Buffer diagnostics |
| `<leader>sh` | Help pages |
| `<leader>sH` | Highlights |
| `<leader>si` | Icons |
| `<leader>sj` | Jumps |
| `<leader>sk` | Keymaps |
| `<leader>sl` | Location list |
| `<leader>sm` | Marks |
| `<leader>sM` | Man pages |
| `<leader>sp` | Plugin spec |
| `<leader>sq` | Quickfix list |
| `<leader>sR` | Resume |
| `<leader>su` | Undo history |
| `<leader>uC` | Colorschemes |
| `gd` | Goto definition |
| `gD` | Goto declaration |
| `gr` | References |
| `gI` | Goto implementation |
| `gy` | Goto type definition |
| `<leader>ss` | LSP symbols |
| `<leader>sS` | LSP workspace symbols |

**Other keymaps:**

| Key | Action |
|---|---|
| `<leader>bS` | Select scratch buffer |
| `<leader>bd` | Delete buffer |
| `<leader>bs` | Toggle scratch buffer |
| `<leader>fR` | Rename file |
| `<leader>gB` | Git browse |
| `<leader>gg` | Lazygit |
| `<leader>nd` | Dismiss notifications |
| `<leader>nh` | Notification history |
| `<leader>tZ` | Toggle zoom |
| `<leader>tz` | Toggle zen mode |
| `<c-/>` | Toggle terminal |
| `]]` / `[[` | Next/prev word reference |

**VeryLazy init:** registers debug globals (`dd`, `bt`), sets up toggles for diagnostics, treesitter, inlay hints, indent, dim.

**Toggle keymaps (via Snacks.toggle):**

| Key | Toggle |
|---|---|
| `<leader>ud` | Diagnostics |
| `<leader>uT` | Treesitter |
| `<leader>uh` | Inlay hints |
| `<leader>ug` | Indent guides |
| `<leader>uD` | Dim |

#### `luukvbaal/statuscol.nvim`

**File:** `lua/plugins/statuscol.lua`

Custom status column with fold, diagnostic sign, line number, general signs, and gitsigns columns. Ignored for `lazy`, `mason`, `snacks_dashboard`.

#### `rachartier/tiny-inline-diagnostic.nvim`

**File:** `lua/plugins/tiny-inline-diagnostic.lua`

Inline diagnostics with source display. Multiline support enabled.  
Sets `virtual_text = false` in `vim.diagnostic.config`.

#### `rasulomaroff/reactive.nvim`

**File:** `lua/plugins/reactive.lua`

Mode-reactive cursorline, cursor, and mode message highlighting.

#### `sphamba/smear-cursor.nvim`

**File:** `lua/plugins/smear-cursor.lua`

Animated cursor movement. Disabled in Neovide.

#### `brenoprata10/nvim-highlight-colors`

**File:** `lua/plugins/nvim-highlight-colors.lua`

Highlights hex, rgb, hsl, CSS variables, named colors, and Tailwind classes inline (virtual symbol `■`).

#### `tris203/precognition.nvim`

**File:** `lua/plugins/precognition.lua`

**Trigger:** `VeryLazy`

Shows motion hints (w, b, e, ^, $, etc.) as virtual text. Hidden by default (`startVisible = false`).

#### `oribarilan/lensline.nvim`

**File:** `lua/plugins/lensline.lua`

**Trigger:** `LspAttach`

Code lens lines showing usage counts and last author. Two profiles:
- `basic`: usages (refs) + last author, all lines, above
- `informative`: usages (refs/defs/impls) + diagnostics + complexity, focused, inline

#### `psliwka/vim-dirtytalk`

**File:** `lua/plugins/vim-dirtytalk.lua`

Adds `programming` to `spelllang` for spell-checking code-related words.  
**Build:** `:DirtytalkUpdate`

---

### Navigation & Motion

#### `folke/flash.nvim`

**File:** `lua/plugins/flash.lua`

**Trigger:** `VeryLazy`

Fast jump navigation using character-based search.

**Keymaps:**

| Mode | Key | Action |
|---|---|---|
| n/x/o | `s` | Flash jump |
| o/x | `S` | Flash treesitter |
| o | `r` | Remote flash |
| c | `<C-s>` | Toggle flash search |
| o/x | `R` | Flash treesitter search |

`f`/`F`/`t`/`T` work normally (`,` removed from char mode keys).  
`nohlsearch` enabled after jump.

#### `mrjones2014/smart-splits.nvim`

**File:** `lua/plugins/smart-splits.lua`

Resize and navigate splits intelligently.

**Keymaps:**

| Key | Action |
|---|---|
| `<A-h/j/k/l>` | Resize left/down/up/right |
| `<C-h/j/k/l>` | Move cursor left/down/up/right |
| `<C-\>` | Move to previous window |
| `<leader><leader>h/j/k/l` | Swap buffer left/down/up/right |

#### `s1n7ax/nvim-window-picker`

Quick window selection for split navigation.  
**Version:** 2.*

#### `chrisgrieser/nvim-origami`

**File:** `lua/plugins/nvim-origami.lua`

**Trigger:** `VeryLazy`

Enhanced folding with LSP fold support and treesitter fallback.

**Features:**
- LSP folds with treesitter fallback
- Pause folds on search
- Foldtext with line count, diagnostic count, gitsigns count
- Auto-fold `comment` and `imports` kinds on open
- Modifies `h`, `l`, `$` to be fold-aware

**Additional keymaps:**

| Key | Action |
|---|---|
| `<Left>` | Fold (same as `h`) |
| `<Right>` | Unfold (same as `l`) |
| `<End>` | Unfold recursively (same as `$`) |

#### `bassamsdata/namu.nvim`

**File:** `lua/plugins/namu.lua`

LSP symbol picker with rich filtering, multiselect, and preview.

**Keymaps:**

| Key | Action |
|---|---|
| `<localleader>tnb` | Buffer symbols |
| `<localleader>tnw` | Workspace symbols |
| `<localleader>tnW` | Watchtower symbols |
| `<localleader>tnd` | Diagnostics |
| `<localleader>tnc` | Ctags |
| `<localleader>tnh` | Help |

**Window:** auto-size, rounded border, 60% width/height ratio.  
**Multiselect:** `<Tab>`/`<S-Tab>`/`<C-a>`/`<C-l>`

---

### Editing

#### `kylechui/nvim-surround`

**File:** `lua/plugins/nvim-surround.lua`

**Trigger:** `VeryLazy`  
**Version:** `^3.0.0`

Add, change, delete surroundings (brackets, quotes, tags, etc.).

#### `windwp/nvim-autopairs`

**File:** `lua/plugins/nvim-autopairs.lua`

**Trigger:** `InsertEnter`

Auto-close brackets and quotes. Integrates with treesitter.  
Fast wrap: `<C-e>`  
Disabled for: `TelescopePrompt`, `spectre_panel`, `snacks_picker_input`

#### `Wansmer/treesj`

**File:** `lua/plugins/treesj.lua`

Split and join code blocks using treesitter.

**Dependencies:** `nvim-treesitter`  
**Custom lang:** dockerfile (run, env, label, copy, add instructions)

**Keymaps:**

| Key | Action |
|---|---|
| `<localleader>ft` | Toggle split/join |
| `<localleader>fs` | Split |
| `<localleader>fS` | Split recursive |

#### `monaqa/dial.nvim`

**File:** `lua/plugins/dial.lua`

Increment/decrement numbers, booleans, dates, casing styles, and more.

**Keymaps:** `<C-a>`/`<C-x>` (normal + visual), `g<C-a>`/`g<C-x>` (visual)

**Augends by filetype:**

| Filetype | Augends |
|---|---|
| default | decimal, hex, date, bool, camelCase/snake_case/PascalCase/SCREAMING_SNAKE_CASE |
| go | decimal, hex, bool, `&&`/`\|\|` |
| typescript | decimal, hex, bool, `let`/`const`, casing |
| markdown | decimal, markdown headers |
| yaml / toml | decimal, semver |

#### `sQVe/sort.nvim`

**File:** `lua/plugins/sort.lua`

Sort lines, selections, and delimited items.

**Delimiters:** `,`, `|`, `;`, `:`, space, tab  
**Natural sort:** enabled

**Keymaps:**

| Key | Action |
|---|---|
| `go` | Sort operator |
| `io` / `ao` | Inner/around sort textobject |
| `]O` / `[O` | Next/prev delimiter |

#### `mcauley-penney/tidy.nvim`

**File:** `lua/plugins/tidy.lua`

Removes trailing whitespace and blank lines on save.

**Keymaps:**

| Key | Action |
|---|---|
| `<localleader>tt` | Toggle tidy |
| `<localleader>tr` | Run tidy manually |

#### `gregorias/toggle.nvim`

**File:** `lua/plugins/toggle.lua`

Toggle vim options with keymaps.

**Prefixes:** `yo` (toggle), `[o` (previous), `]o` (next), `yos` (status dashboard)

#### `jameswolensky/marker-groups.nvim`

**File:** `lua/plugins/marker-groups.lua`

Group and manage marks. Uses `snacks` picker.

**Dependencies:** `nvim-lua/plenary.nvim`, `ibhagwan/fzf-lua`, `folke/snacks.nvim`

#### `KieranCanter/candela.nvim`

**File:** `lua/plugins/candela.lua`

Advanced search and highlight tool with lightbox diff view and color palette.

---

### File Management

#### `mikavilpas/yazi.nvim`

**File:** `lua/plugins/yazi.lua`

**Trigger:** `VeryLazy`

Yazi file manager integration. Opens instead of netrw for directories.

**Keymaps:**

| Mode | Key | Action |
|---|---|---|
| n/v | `<localleader>yf` | Open yazi at current file |
| n/v | `<localleader>yd` | Open yazi at cwd |
| n | `<localleader>yr` | Resume last yazi session |

#### `xvzc/chezmoi.nvim`

**File:** `lua/plugins/chezmoi.lua`

**Trigger:** `VeryLazy`

Chezmoi dotfile management integration. Auto-watches and applies chezmoi files on open.

**Keymaps:**

| Key | Action |
|---|---|
| `<leader>fc` | Search chezmoi managed files |

#### `2kabhishek/nerdy.nvim`

Nerd font icon picker using snacks.  
**Command:** `Nerdy`

---

### Search

#### `folke/trouble.nvim`

**File:** `lua/plugins/trouble.lua`

**Trigger:** `VeryLazy`; **Command:** `Trouble`

Diagnostics, quickfix, and location list in a pretty UI.

**Keymaps:**

| Key | Action |
|---|---|
| `<localleader>T` | Diagnostics (all) |
| `<localleader>db` | Buffer diagnostics |
| `<localleader>dL` | Location list |
| `<localleader>dq` | Quickfix list |

#### `hat0uma/csvview.nvim`

**File:** `lua/plugins/csview.lua`

CSV file viewer with Excel-like navigation.

**Filetype:** `csv`; **Commands:** `CsvViewEnable`, `CsvViewDisable`, `CsvViewToggle`

**Keymaps (in csv files):**

| Key | Action |
|---|---|
| `<Tab>` / `<S-Tab>` | Next/prev field |
| `<Enter>` / `<S-Enter>` | Next/prev row |
| `if` / `af` | Inner/outer field textobject |

---

### Notes & Writing

#### `obsidian-nvim/obsidian.nvim`

**File:** `lua/plugins/obsidian.lua`

Obsidian vault integration. Only loads if `NOTIZEN_DIR` env var is set and the vault directory exists.

**Vault:** `$NOTIZEN_DIR/obsidian/main`  
**Picker:** `snacks.pick`  
**Completion:** blink  
**Link style:** wiki

**Daily notes:** folder `notes/dailies`, workdays only, format `%Y-%m-%d`

**Keymaps:**

| Key | Action |
|---|---|
| `<leader>fo` | Quick switch |
| `<leader>oN` | New note from template |
| `<leader>oT` | Tags |
| `<leader>ol` | New link (visual) |
| `<leader>on` | New note |
| `<leader>op` | Preview |
| `<leader>or` | Rename note |
| `<leader>ojt` | Today's daily |
| `<leader>ojT` | Tomorrow's daily |
| `<leader>ojy` | Yesterday's daily |
| `<leader>so` | Search in notes |

#### `MeanderingProgrammer/render-markdown.nvim`

**File:** `lua/plugins/render-markdown.lua`

Renders markdown with visual improvements (headers, lists, tables, etc.).

**Dependencies:** `nvim-treesitter`, `nvim-web-devicons`

#### `toppair/peek.nvim`

**File:** `lua/plugins/peek.lua`

Markdown live preview using Deno.

**Build:** `deno task --quiet build:fast`  
**Commands:** `PeekOpen`, `PeekClose`

---

### Database

#### `kristijanhusak/vim-dadbod-ui`

**File:** `lua/plugins/vim-dadbod-ui.lua`

Database UI for vim-dadbod.

**Dependencies:** `tpope/vim-dadbod`, `vim-dadbod-completion`

**Keymaps:**

| Key | Action |
|---|---|
| `<leader>tD` | Toggle DBUI |

**Config:** right position, nerd fonts, nvim-notify.

---

### REST / HTTP

#### `mistweaverco/kulala.nvim`

**File:** `lua/plugins/kulala.lua`

HTTP client for `.http` files.

**Keymaps (in http files):**

| Key | Action |
|---|---|
| `<leader>rr` | Run request |
| `<leader>ra` | Run all requests |
| `<leader>ri` | Inspect request |
| `<leader>rc` | Copy as cURL |
| `<leader>rp` | Open scratchpad |
| `<leader>rt` | Toggle view |
| `<leader>rj` / `<leader>rk` | Jump next/prev request |

---

### Diagnostics & Code Actions

#### `rachartier/tiny-code-action.nvim`

**File:** `lua/plugins/tiny-code-action.lua`

**Trigger:** `LspAttach`

Code actions with delta diff preview.

**Backend:** `delta`  
**Picker:** `snacks`

**Keymaps:**

| Mode | Key | Action |
|---|---|---|
| n/x | `<leader>ca` | Code actions |

#### `folke/todo-comments.nvim`

**File:** `lua/plugins/todo-comments.lua`

**Dependencies:** `nvim-lua/plenary.nvim`

Highlights and searches TODO/FIXME/HACK/WARN/NOTE/PERF/TEST comments.

Uses ripgrep for searching. Pattern: `\b(KEYWORDS):`.

---

### Session & Project

#### `folke/persistence.nvim`

**File:** `lua/plugins/persistence.lua`

**Trigger:** `BufReadPre`

Session management. Saves/restores sessions per directory and git branch.

**Session dir:** `stdpath('state')/sessions/`

#### `saecki/crates.nvim`

**File:** `lua/plugins/crates.lua`

Rust crates.io dependency management for `Cargo.toml`.

**Trigger:** `BufRead Cargo.toml`

#### `vuki656/package-info.nvim`

**File:** `lua/plugins/package-info.lua`

npm package version info for `package.json`.

**Dependencies:** `MunifTanjim/nui.nvim`

---

### Miscellaneous

#### `stevearc/aerial.nvim`

**File:** `lua/plugins/aerial.lua`

Code symbol outline and navigation.

**Backends:** lsp, treesitter, markdown, asciidoc, man  
**Layout:** right side, 20–40 cols wide, window placement

**Keymaps:**

| Key | Action |
|---|---|
| `<localleader>ta` | Toggle aerial |
| `{` / `}` | Prev/next symbol (in buffer) |

#### `hedyhli/outline.nvim`

**File:** `lua/plugins/outline.lua`

Symbol outline panel (alternative to aerial).

**Keymaps:**

| Key | Action |
|---|---|
| `<localleader>to` | Toggle outline |

#### `kevinhwang91/nvim-bqf`

**File:** `lua/plugins/nvim-bqf.lua`

Better quickfix window with preview.

**Filetype:** `qf`  
**Preview border:** box-drawing characters

#### `folke/flash.nvim`

See [Navigation & Motion](#navigation--motion).

#### `nvzone/typr`

**File:** `lua/plugins/typr.lua`

Typing practice plugin.

**Commands:** `Typr`, `TyprStats`  
**Dependencies:** `nvzone/volt`

#### `yochem/jq-playground.nvim`

**File:** `lua/plugins/jq-playground.lua`

Interactive `jq` query editor with live output.

#### `neumachen/yank-file-path.nvim`

**File:** `lua/plugins/yank-file-path.lua`

Yank file path in various formats.

#### `b0o/schemastore.nvim`

**File:** `lua/plugins/schemastore.lua`

JSON/YAML schema store integration (used by `jsonls` and `yamlls`).

#### `xvzc/chezmoi.nvim`

See [File Management](#file-management).

---

## LSP Servers

All servers in `lsp/` are auto-discovered and enabled via `vim.lsp.enable()`. TypeScript server (`ts_ls` or `vtsls`) is selected via `vim.g.lsp_typescript_server`.

### `lua_ls` — Lua Language Server
**Install:** `mise use -g lua-language-server`  
**Filetypes:** `lua`  
Skips custom runtime config if `.luarc.json` / `.luarc.jsonc` is found in workspace.  
Configures LuaJIT runtime and Neovim runtime library.

### `gopls` — Go Language Server
**Install:** `go install golang.org/x/tools/gopls@latest`  
**Filetypes:** `go`, `gomod`, `gowork`, `gotmpl`  
**Root markers:** `go.sum`, `go.mod`, `.git`, `go.work`

### `golangci-lint-langserver` — Go Linter
**Filetypes:** `go`, `gomod`  
Supports both golangci-lint v1 (`--out-format=json`) and v2 (`--output.json.path=stdout`). Version is auto-detected.

### `ts_ls` — TypeScript Language Server
**Install:** `npm install -g typescript typescript-language-server`  
**Filetypes:** js, jsx, ts, tsx  
**Root markers:** `tsconfig.json`, `jsconfig.json`, `package.json`, `.git`  
Inlay hints, code lens (implementations + references), format settings from vim options.

### `vtsls` — VTS Language Server (alternative to ts_ls)
**Install:** `npm install -g @vtsls/language-server`  
**Filetypes:** js, jsx, ts, tsx  
**Root markers:** `tsconfig.json`, `package.json`, `jsconfig.json`, `.git`  
Server-side fuzzy match, move-to-file code action, workspace tsdk auto-use.

### `biome` — Biome LSP
**Filetypes:** astro, css, graphql, js, jsx, json, jsonc, svelte, ts, tsx, vue  
**Root markers:** `biome.json`, `biome.jsonc`, `.git`  
Defines global `biome_fix()` and `biome_fix_unsafe()` functions.  
**Keymaps (on attach):** `<leader>cb` (fix), `<leader>cB` (fix unsafe)

### `eslint` — ESLint Language Server
**Install:** `npm i -g vscode-langservers-extracted`  
**Filetypes:** js, jsx, ts, tsx, vue, svelte, astro  
**Root markers:** various `.eslintrc*` and `eslint.config.*` files  
Format on save enabled, runs `onType`.

### `jsonls` — JSON Language Server
**Install:** `npm i -g vscode-langservers-extracted`  
**Filetypes:** `json`, `jsonc`  
Schemas loaded from `schemastore.nvim`.

### `yamlls` — YAML Language Server
**Filetypes:** yaml, yaml.docker-compose, yaml.gitlab, yaml.helm-values  
**Root markers:** `.git`  
Schemas from `schemastore.nvim`. Format disabled (uses conform/prettier). Telemetry disabled.

### `docker_language_server` — Docker Language Server
**Install:** `mise install -g github:docker/docker-language-server`  
**Filetypes:** `dockerfile`, `yaml.docker-compose`  
**Root markers:** Dockerfile, docker-compose.yaml/yml, compose.yaml/yml, docker-bake files

### `helm_ls` — Helm Language Server
**Filetypes:** `helm`, `yaml.helm-values`  
**Root markers:** `Chart.yaml`

### `tailwindcss` — Tailwind CSS Language Server
**Install:** `npm install -g @tailwindcss/language-server`  
**Filetypes:** Most HTML, CSS, JS, TS, and component framework types + slim, erb, templ, etc.  
**Root markers:** `tailwind.config.*`, `postcss.config.*`

### `ruby-lsp` — Ruby Language Server
**Install:** `gem install ruby-lsp`  
**Filetypes:** `ruby`, `rspec`, `Gemfile`  
**Root markers:** `Gemfile`, `.git`

### `pyright` — Python Language Server
**Install:** `uv tool install pyright@latest`  
**Filetypes:** `python`  
Diagnostic mode: `openFilesOnly`.

### `marksman` — Markdown Language Server
**Filetypes:** `markdown`, `markdown.mdx`  
**Root markers:** `.marksman.toml`, `.git`

### `taplo` — TOML Language Server
**Filetypes:** `toml`  
**Root markers:** `.taplo.toml`, `taplo.toml`, `.git`

### `erlang_ls` — Erlang Language Server
**Filetypes:** `erlang`  
**Root markers:** `rebar.config`, `erlang.mk`, `.git`

### `harper_ls` — Harper Grammar/Spell Checker
**Filetypes:** c, cpp, cs, gitcommit, go, html, java, js, lua, markdown, nix, python, ruby, rust, swift, toml, ts, tsx, haskell, cmake, typst, php, dart, clojure, sh  
**Root markers:** `.git`  
Diagnostic severity: `hint`. American English dialect. Many linters enabled.

### `codebook` — Codebook Spell Checker
**Install:** `mise use -g cargo:codebook`  
**Filetypes:** c, css, gitcommit, go, haskell, html, java, js, jsx, lua, markdown, php, python, ruby, rust, toml, text, ts, tsx  
**Root markers:** `.git`, `codebook.toml`, `.codebook.toml`

The `codebook.toml` file in the repo root defines allowed words for the spell checker.

---

## Local Plugins (plugin/)

These are standalone scripts in `plugin/` (not managed by lazy.nvim).

### `plugin/scooter.lua` — Scooter Search/Replace

Terminal-based search-and-replace tool using the `scooter` CLI.

**Functions:**
- `_G.EditLineFromScooter(file_path, line)` — Opens file at line from scooter results
- `open_scooter()` — Toggles or opens scooter in a float terminal
- `open_scooter_with_text(text)` — Opens scooter with pre-filled search text

**Keymaps:**

| Mode | Key | Action |
|---|---|---|
| n | `<leader>tS` | Open scooter |
| v | `<localleader>sr` | Search and replace selected text |

### `plugin/treesit-navigator.lua` — Treesitter Node Navigator

Custom treesitter-aware navigation with a floating tree view.

**Config:**

| Option | Default |
|---|---|
| Highlight source node | `Visual` |
| Highlight tree node | `PmenuSel` |
| Tree window border | `solid` |
| Keymaps prefix | `<leader>T` |

**Keymaps:**

| Key | Action |
|---|---|
| `<leader>Tt` | Show treesitter tree |
| `<leader>Tl` | Next sibling |
| `<leader>Th` | Previous sibling |
| `<leader>Tk` | Parent node |
| `<leader>Tj` | First child node |
| `<leader>T0` | Node start |
| `<leader>T$` | Node end |

**Transient keymaps:** After opening the tree, `h`/`l`/`j`/`k`/`0`/`$` temporarily bound for navigation without prefix (cleared on cursor move or buffer leave).

---

## Utility Modules (lua/utils/)

### `utils/path.lua`

| Function | Description |
|---|---|
| `join_path(...)` | Join path components with OS separator |
| `is_git_repo()` | Returns true if cwd is inside a git repo |
| `get_git_root()` | Returns git repo root directory |
| `get_root_directory()` | Git root or cwd fallback |
| `get_nvim_config_directory()` | Returns `stdpath("config")` |
| `dir_exists(path, opts)` | Checks directory existence; optional notifications |

### `utils/lsp.lua`

| Function | Description |
|---|---|
| `action` (metatable) | Returns a function that applies a specific LSP code action by name |
| `biome_config_path()` | Returns directory containing `biome.json` (cwd or git root) |
| `biome_config_exists()` | True if `biome.json` is found |
| `dprint_config_path()` | Returns directory containing `dprint.json` |
| `dprint_config_exist()` | True if `dprint.json` is found |
| `deno_config_exist()` | True if `deno.json`/`deno.jsonc` is found |
| `spectral_config_path()` | Returns directory containing `.spectral.yaml` |
| `eslint_config_exists()` | True if any ESLint config file is found |

### `utils/cspell.lua`

| Function | Description |
|---|---|
| `add_word_to_c_spell_dictionary()` | Prompts to add word under cursor to `spell/en.utf-8.add` |
| `add_word_from_diagnostics_to_c_spell_dictionary()` | Adds unknown word from cspell diagnostic to dictionary |

### `utils/ext.lua`

| Function | Description |
|---|---|
| `pcall(msg, func, ...)` | Wraps `xpcall` with `vim.notify` error reporting; `msg` is optional |

### `utils/project.lua`

Provides `:ProjectSettings` and `:ProjectSettingsHelp` commands for creating `.nvim-config.lua` project-local config files interactively.

---

## Filetype Plugins (after/ftplugin/)

| File | Effect |
|---|---|
| `tex.lua` | `expandtab = true` |
| `typst.lua` | `expandtab = true` |
| `txt.lua` | `expandtab = true` |
| `markdown.lua` | `expandtab = true` |
| `qf.lua` | `wrap = true` |
| `slim.lua` | Sets default highlight links for slim treesitter captures |

## Filetype Detection (ftdetect/)

| File | Effect |
|---|---|
| `slim.lua` | Sets `filetype = slim` for `*.slim` files |
