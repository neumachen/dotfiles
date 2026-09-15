# NEOVIM CONFIGURATION

## OVERVIEW

Lua configuration with lazy.nvim plugins and Neovim 0.11+ native LSP discovery.

## STRUCTURE

```text
exact_nvim/
├── init.lua                  # Startup orchestration and LSP activation
├── exact_lua/exact_config/    # Settings, autocmds, Lazy, global keymaps
├── exact_lua/exact_plugins/   # Lazy plugin specs, themes, Snacks modules
├── exact_lua/exact_utils/     # Project config, tool checks, keymap export
├── exact_lua/exact_vscode/    # VSCode-specific Lazy import
├── exact_lsp/                # One returned config table per LSP server
├── exact_plugin/             # Native runtime plugin scripts
├── exact_ftdetect/           # Filetype detection
└── exact_after/              # Filetype overrides and Treesitter queries
```

Lua imports use deployed names: `config`, `plugins`, `utils`, and `vscode`.
For example, `require('config.lazy')` maps to `exact_lua/exact_config/lazy.lua`.

## WHERE TO LOOK

| Task | Source path relative to this directory |
| --- | --- |
| Leader keys, options, mise shim PATH | `exact_lua/exact_config/settings.lua` |
| Global mappings, `FormatDisable[!]`, `FormatEnable` | `exact_lua/exact_config/keymaps.lua` |
| Autoread, buffer/window cleanup, lockfile sync | `exact_lua/exact_config/autocmds.lua` |
| Plugin installation and imports | `exact_lua/exact_config/lazy.lua` |
| Formatter / linter routing | `exact_lua/exact_plugins/conform.lua`, `nvim-lint.lua` |
| `ToolDoctor` binary checks | `exact_lua/exact_utils/doctor.lua` |
| `DumpKeymaps` / `KeymapsDump` JSON and Markdown export | `exact_lua/exact_utils/keymaps_dump.lua` |
| `ExrcEdit`, `ExrcNew`, `ExrcTrust`, `ExrcDelete` and `Nvimrc*` aliases | `exact_lua/exact_utils/exrc.lua` |

## STARTUP AND LOCAL CONVENTIONS

- `init.lua` loads settings → autocmds → Lazy → keymaps, then registers utilities.
- Normal startup selects `tokyonight-storm`; VSCode instead triggers the
  `NvimIdeKeymaps` user event and skips this theme/LSP activation branch.
- LSP names come from runtime `stdpath('config')/lsp/*.lua`, sourced here from
  `exact_lsp/`. Adding a file participates in automatic discovery.
- Discovery removes both TypeScript candidates and enables only
  `vim.g.lsp_typescript_server` (default `ts_ls`, alternative `vtsls`).
- Project-local `.nvim.lua` uses built-in `exrc` and Neovim's `:trust` mechanism.
  The `Exrc*` utilities manage those files; they are not another loader.
- `ToolDoctor` is registered at startup but runs only when invoked.
  `DumpKeymaps!` additionally loads all Lazy plugins before exporting.

## SIDE EFFECTS AND GOTCHAS

- Loading `config.lazy` can clone lazy.nvim and install missing plugins.
  When `$NVIM` is set, its setup returns early with only flatten.nvim.
- `LazyUpdate`, `LazySync`, and `LazyInstall` trigger an autocmd that runs
  `chezmoi re-add` on the deployed `lazy-lock.json`, modifying source state.
- `config.autocmds` schedules chezmoi edit watching for files under `DOTFILES_DIR`.
- Root `docs/neovim-plugins.md` describes `enable_extra_plugins`; currently Lazy builds
  a local `specs` table for it but passes a separate literal `spec` to setup.
  Do not assume those prepared extra imports are active.

## SYNTAX-ONLY CHECK

From the repository root, compile a selected Lua file without executing it:

```sh
NVIM_LOG_FILE=/dev/null nvim --headless -u NONE -i NONE -n \
  +'lua assert(loadfile("private_dot_config/exact_nvim/init.lua"))' +qa
```

Change the filename for the touched module. This does not validate runtime wiring.
