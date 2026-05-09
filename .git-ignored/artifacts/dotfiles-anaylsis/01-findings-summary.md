# Neovim Configuration Audit - Findings Summary

**Repository:** `https://github.com/neumachen/dotfiles.git`  
**Audit Date:** 2026-05-09  
**Auditor:** AI Principal Engineer Review  
**Scope:** Neovim configuration at `private_dot_config/exact_nvim/`

---

## Executive Summary

This is a **well-maintained, modern Neovim configuration** using lazy.nvim as the plugin manager. The configuration follows Neovim 0.11+ conventions and demonstrates sophisticated Lua-based configuration practices. The repository is chezmoi-managed, enabling portable dotfile deployment.

**Key Strengths:**
- Uses Neovim 0.11+ native LSP (`vim.lsp.enable()`) instead of mason.nvim
- Dynamic LSP server discovery from `lsp/` directory
- Project-local settings via `.nvim-config.lua`
- VSCode-Neovim hybrid support
- Comprehensive existing documentation at `docs/neovim-plugins.md`

**Total Plugins in lazy-lock.json:** 90 plugins  
**Total Plugin Configuration Files:** 66 files in `lua/plugins/`  
**LSP Configurations:** 19 language servers

---

## Architecture Overview

### Entry Point Structure

```
init.lua
├── config.settings     # Global Neovim options, leader keys, diagnostics
├── .nvim-config.lua    # Project-local (optional, git-ignored)
├── config.autocmds     # Custom autocommands
├── config.lazy         # lazy.nvim bootstrap and setup
├── config.keymaps      # Core keybindings
└── LSP enable          # vim.lsp.enable() for all servers in lsp/
```

### Leader Keys

| Key | Role |
|-----|------|
| `,` | `mapleader` |
| `<Space>` | `maplocalleader` |

### Directory Structure

```
exact_nvim/
├── init.lua                 # Entry point
├── lazy-lock.json           # Plugin version lockfile
├── biome.json               # Biome formatter config (for nvim config itself)
├── exact_lua/
│   ├── exact_config/        # Core configuration modules
│   ├── exact_plugins/       # Plugin specifications
│   ├── exact_utils/         # Utility modules
│   └── exact_vscode/        # VSCode-specific settings
├── exact_lsp/               # LSP server configurations
├── exact_plugin/            # Local plugin scripts
├── exact_after/             # After-plugin ftplugin and queries
├── exact_ftdetect/          # Filetype detection
└── exact_spell/             # Spell dictionary
```

---

## Plugin Categories and Counts

| Category | Count | Notes |
|----------|-------|-------|
| Core/Libraries | 5 | plenary, devicons, mini.icons, lspconfig, lazydev |
| Completion | 9 | blink.cmp + 8 sources |
| Treesitter | 6 | Core + textobjects, context, autotag, commentstring, rainbow |
| Git | 6 | gitsigns, neogit, diffview, gitgraph, blame, codediff |
| UI/Appearance | 16 | Themes, statusline, bufferline, noice, etc. |
| Navigation/Motion | 6 | flash, smart-splits, origami, namu, window-picker |
| Editing | 10 | surround, autopairs, dial, sort, treesj, etc. |
| File Management | 3 | yazi, chezmoi, snacks.explorer |
| Fuzzy Finding | 3 | snacks.picker, fzf-lua, marker-groups |
| Notes/Writing | 5 | obsidian, render-markdown, peek, vim-dirtytalk |
| Database | 3 | dadbod, dadbod-ui, dadbod-completion |
| REST/HTTP | 2 | kulala, jq-playground |
| Diagnostics | 3 | trouble, tiny-inline-diagnostic, tiny-code-action |
| Session/Project | 2 | persistence, flatten |
| Miscellaneous | 11 | Various utilities |

---

## Critical Findings

### 1. Duplicate/Overlapping Functionality

#### Git Blame (LOW CONCERN)
- **`gitsigns.nvim`**: Provides current line blame via `current_line_blame`
- **`blame.nvim`**: Fugitive-style full-file blame viewer
- **Analysis:** These serve different purposes. Gitsigns provides inline current-line blame; blame.nvim provides full-buffer blame views. **KEEP BOTH.**

#### Symbol/Outline Viewers (INVESTIGATE)
- **`aerial.nvim`**: Code outline via LSP/treesitter
- **`outline.nvim`**: Code outline via LSP/treesitter  
- **`namu.nvim`**: LSP symbol picker with multiselect
- **Snacks picker**: `lsp_symbols()` and `lsp_workspace_symbols()`
- **Analysis:** `aerial.nvim` and `outline.nvim` have very similar functionality. They are both code outline plugins with virtually identical feature sets.
- **Evidence:**
  - `aerial.nvim`: keymap `<localleader>ta` for toggle
  - `outline.nvim`: keymap `<localleader>to` for toggle
- **Recommendation:** **User confirmation required.** Pick one between aerial and outline. Namu serves a different purpose (symbol picker/navigator vs persistent sidebar).

#### Fuzzy Finding
- **`snacks.nvim` picker**: Primary fuzzy finder (used for files, grep, LSP)
- **`fzf-lua`**: Configured but minimal usage visible (only `opts = {}`)
- **Analysis:** fzf-lua appears to be a dependency for some plugins (marker-groups, yazi integrations) rather than direct use.
- **Evidence:** `fzf-lua.lua` has `cmd = 'FzfLua'` only, no keymaps defined
- **Recommendation:** **KEEP** fzf-lua as dependency. It's used by yazi and marker-groups integrations.

#### Code Actions
- **Neovim native**: `vim.lsp.buf.code_action()` (keymaps commented out in utils/lsp.lua)
- **`tiny-code-action.nvim`**: Enhanced code action picker with delta diff preview
- **Analysis:** Configuration explicitly moved to tiny-code-action. Native is intentionally unused.
- **Recommendation:** **Current state is correct.** No action needed.

### 2. Plugins Without Visible Keymaps or Usage

#### `candela.nvim`
- **Type:** Highlight/color management plugin
- **Evidence:** Full setup in config but **no keymaps** defined
- **Status:** Active project, not archived
- **Recommendation:** **Investigate.** Either define keymaps or confirm it's used via commands only.

#### `codediff.nvim`
- **Type:** Side-by-side diff viewer
- **Command:** `CodeDiff`
- **Evidence:** Has keymaps defined in `keymaps` option but no global keymaps
- **Recommendation:** **Investigate.** Consider adding a keymap to trigger `:CodeDiff` or confirm command usage is sufficient.

#### `package-info.nvim`
- **Type:** npm package.json dependency info
- **Evidence:** Only `require('package-info').setup()` with no keymaps
- **Recommendation:** **User confirmation required.** If used, add keymaps. If not, consider removal.

#### `schemastore.nvim`
- **Type:** JSON/YAML schema provider
- **Evidence:** Only declaration `'b0o/schemastore.nvim'` with no integration visible
- **Risk:** May be used by jsonls/yamlls LSP configs
- **Recommendation:** **INVESTIGATE.** Check LSP configs for schemastore usage. Likely used but integration not visible in plugin file.

### 3. Typo in Artifacts Directory

**Note:** The artifacts directory has a typo: `dotfiles-anaylsis` instead of `dotfiles-analysis`. Preserving as specified per instructions.

### 4. Disabled or Partially Active Features

#### nvim-lint Commented Configuration
```lua
-- TODO:disabled while testing codebook
-- ['*'] = { 'cspell', 'codespell' },
```
- **Impact:** Global spell/code checking is disabled
- **Recommendation:** Complete codebook testing and either restore cspell/codespell or remove if codebook replaces them.

#### Inlay Hints Disabled by Default
```lua
if client:supports_method('textDocument/inlayHints') then
  vim.lsp.inlay_hint.enable(false, { bufnr = args.buf })
end
```
- **Analysis:** Intentional choice. Toggle available via `<leader>uh`.
- **Recommendation:** No action needed.

#### ESLint LSP Disabled by Default
- Per init.lua: ESLint is in `lsp/` but not auto-enabled
- Can be enabled via `vim.g.lsp_on_demands = {"eslint"}`
- **Recommendation:** No action needed. Intentional design.

---

## Plugin Health Assessment

### Plugins Confirmed Active and Maintained
All plugins in lazy-lock.json were sampled and **none are archived**. All checked plugins show recent activity (within 2026).

### Plugins Requiring Version/Compatibility Notes

| Plugin | Note |
|--------|------|
| `nvim-treesitter` | Uses `main` branch (required for Neovim 0.11+) |
| `nvim-treesitter-textobjects` | Uses `main` branch |
| `blink.cmp` | Requires `cargo +nightly` for build |
| `peek.nvim` | Requires `deno` for Markdown preview |
| `LuaSnip` | Version pinned to `v2.*` |

---

## External Tool Dependencies

### Mise (`.config/mise/private_config.toml`)

The following tools are installed via mise and used by Neovim:

| Tool | Neovim Usage |
|------|--------------|
| `lua-language-server` | LSP |
| `neovim` | Editor itself |
| `taplo` | TOML formatter |
| `stylua` | Lua formatter |
| `ripgrep` | grep integration, blink-ripgrep |
| `fzf` | fzf-lua dependency |
| `jq` | jq-playground |
| `yazi` | yazi.nvim |
| `delta` | tiny-code-action diff preview |
| `codebook-lsp` | (cargo) Potential future spell checker |
| `harper-ls` | (cargo) Grammar/prose LSP |
| `selene` | Lua linter (not configured in nvim-lint) |
| `hadolint` | Dockerfile linter |
| `deno` | peek.nvim, deno_fmt |

### Missing Tool Configurations

| Tool in mise | Missing nvim-lint config |
|--------------|-------------------------|
| `selene` | Not in linters_by_ft |
| `sqruff` | Not in linters_by_ft (sql) |

---

## Configuration Quality Notes

### Strengths

1. **Excellent documentation** - The `docs/neovim-plugins.md` file is comprehensive
2. **Modern Neovim practices** - Uses 0.11+ native LSP enable
3. **Clean separation** - Utils modules are well-organized
4. **VSCode compatibility** - Full VSCode-Neovim support
5. **Chezmoi integration** - Auto-apply on save within dotfiles
6. **Conditional loading** - Extra plugins system, on-demand LSP

### Areas for Improvement

1. **Duplicate outline plugins** - aerial.nvim vs outline.nvim
2. **Unused plugins** - Some have no visible keymaps
3. **Commented code** - nvim-lint has disabled config
4. **Missing linter configs** - selene, sqruff not configured

---

## Risk Assessment Summary

| Risk Level | Count | Items |
|------------|-------|-------|
| **High** | 0 | - |
| **Medium** | 1 | Duplicate outline plugins |
| **Low** | 4 | Unused keymaps, commented config, missing linter setup |
| **Info** | 3 | Optional cleanups, preferences |

---

## Next Steps

See companion documents:
1. `02-plugin-audit-matrix.md` - Detailed plugin-by-plugin analysis
2. `03-recommendations.md` - Prioritized action items
