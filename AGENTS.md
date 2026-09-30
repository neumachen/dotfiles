# PROJECT KNOWLEDGE BASE

Generated: 2026-09-15 | Source snapshot: `f1d5804a` | Branch: `main`

## CHATGPT / CODEX ROLE AND AUTHORITY

ChatGPT and Codex are analysts and prompt authors for this repository. Claude
Code is the implementation agent. This boundary applies throughout the checkout
and to any subagents used by ChatGPT or Codex.

- **Do not implement changes.** Do not create, edit, delete, refactor, format,
  or patch application code, scripts, tests, configuration, dependencies,
  generated implementation files, or deployed dotfiles. Do not use tools,
  formatters, code generators, or delegated agents to implement indirectly.
- Inspect files and Git state, investigate problems, analyze proposed or completed
  work, and run read-only checks. Keep confirmed evidence, hypotheses, and
  unverified outcomes distinct. Do not apply configuration, install dependencies,
  reload services, or mutate live application state as part of an investigation.
- Generate, analyze, and provide self-contained prompts for **Claude Code** to
  make the changes. Include the goal, relevant paths, evidence, constraints,
  acceptance criteria, validation expectations, and unresolved decisions. Provide
  the prompt to the user; do not dispatch implementation automatically.
- Requests to fix, build, refactor, or improve something mean investigate and
  prepare a Claude Code implementation prompt. They do not implicitly grant
  ChatGPT or Codex permission to implement. Implementation requires the user to
  explicitly change this role boundary first.
- Prompt and analysis documents are permitted deliverables. Repository instruction
  files may be edited when the user explicitly requests an instruction update.
  These exceptions do not authorize changes to implementation files.
- **Git commits are permitted.** ChatGPT or Codex may inspect, stage, and commit
  permitted prompt/instruction artifacts or implementation changes already made
  by Claude Code when those changes are within the user's requested commit scope.
  Permission to commit is not permission to implement, repair, or rewrite the
  changes being committed. Exclude unrelated work and provide a Claude Code
  correction prompt if a defect needs implementation. Commit permission does not
  imply permission to push or deploy.
- Apply this role boundary when interpreting all implementation-oriented guidance
  below or in child instruction files. Source-editing conventions describe how
  Claude Code should implement; they do not authorize ChatGPT or Codex to do so.

## OVERVIEW

Personal and work development-machine dotfiles managed by chezmoi. This checkout
is the source tree; its encoded filenames deploy into the user's home directory.
Most content is shell, Lua, TOML/JSON configuration, and agent/vault templates.

## STRUCTURE

```text
dotfiles/
├── .chezmoi.yaml.tmpl       # Source location, identity prompts, diff/merge setup
├── .chezmoiignore          # Target exclusions; distinct from Git exclusions
├── .chezmoiexternal.toml   # Downloaded dependencies and theme assets
├── .chezmoiremove          # Explicit cleanup of obsolete target paths
├── .chezmoiscripts/        # Apply-time installation and synchronization hooks
├── .chezmoitemplates/      # Shared shell fragments for those hooks
├── dot_local/bin/          # Executable utilities; child AGENTS.md
├── private_dot_config/    # XDG application configuration
│   ├── exact_nvim/         # Neovim modules and LSP configs; child AGENTS.md
│   └── exact_aider-desk/   # Agent profiles, rules, skills; child AGENTS.md
├── MeinCodex/Notizen/Obsidian/ # Vault configuration; child AGENTS.md
├── dot_codex/              # Full base config and named config files
├── dot_claude/             # Claude settings source
└── docs/                   # Neovim inventory and tmux/terminfo notes
```

## WHERE TO LOOK

| Task | Source location | Notes |
| --- | --- | --- |
| Bootstrap | `install.sh`, `.chezmoiscripts/` | Installer invokes `chezmoi init --apply` |
| Every-shell environment | `dot_zshenv.tmpl` | XDG paths, `ZDOTDIR`, Zim/mise environment |
| Login PATH | `private_dot_config/exact_zsh/dot_zprofile.tmpl` | Uses `path_force_front` from `private_dot_config/sh/lib.sh` |
| Interactive shell | `private_dot_config/exact_zsh/dot_zshrc`, `zimrc.zsh` in that directory | Interactive behavior and Zim module order |
| Git behavior / identity | `private_dot_config/exact_git/private_config.tmpl`, `private_profile.tmpl` | Separate behavior from identity/signing data |
| Homebrew packages | `private_dot_config/exact_homebrew/Brewfile.tmpl` | XDG Brewfile, not a root `dot_Brewfile.tmpl` |
| Tool versions / tasks | `private_dot_config/exact_mise/private_config.toml`, `exact_conf.d/` | Numbered backend/task fragments |
| Terminal integration | `dot_tmux.conf`, `dot_tmux/`, `private_dot_config/exact_wezterm/` | Check TERM, RGB, clipboard, smart-splits together |
| macOS key/event handling | `private_dot_config/exact_hammerspoon/init.lua` | `symlink_dot_hammerspoon` points to `.config/hammerspoon` |
| Codex / Claude source | `dot_codex/private_config.toml`, `dot_claude/settings.json` | Current Codex source is a full file, not a partial modifier |
| Classic Aider | `private_dot_config/private_aider/` | Separate configuration from AiderDesk |
| macOS preferences / shortcuts | `dot_local/bin/executable_macos-preferences`, `private_dot_config/macos-preferences/profile.json`, `.chezmoiscripts/run_onchange_after_55-macos-preferences.sh.tmpl` | Allowlisted capture/restore via `defaults`; guide in `docs/macos-preferences.md`; `restore` mutates live preferences |

## CODE MAP

| Entry / symbol | Location | Role |
| --- | --- | --- |
| `init.lua` | `private_dot_config/exact_nvim/` | Settings → autocmds → Lazy → keymaps; discovers runtime `lsp/*.lua` |
| `AnalysisEngine.run` | `private_dot_config/exact_aider-desk/exact_skills/shiki-plan/scripts/analyze_dependencies.py` | Parses, groups dependencies, rewrites input task metadata |
| `TaskParser`, `DependencyAnalyzer` | Same scripts directory, `task_parser.py` | Markdown task model and dependency derivation |
| `echo-run`, `echo-log` | `dot_local/bin/executable_echo-run`, `executable_echo-log` | Shared command/logging helpers |
| `obsidian_utils.js` | `MeinCodex/Notizen/Obsidian/Main/scripts/` | Templater helper API; some logic duplicated in local sync plugin |

Discovery used codegraph and Lua LSP. Reference centrality is not reliably
measured across this mixed configuration tree; extensionless shell scripts need
direct inspection and textual caller searches. Do not equate missing graph edges
with an unused script.

## CONVENTIONS

- Claude Code should edit source files in this checkout unless the user explicitly
  requests a target edit. ChatGPT and Codex remain subject to the role boundary above.
- Prefixes have behavior: `dot_` adds a dot, `private_` restricts permissions,
  `executable_` sets executable mode, `symlink_` stores a link target, and
  `exact_` directories can remove unmanaged target entries during apply.
- `.tmpl` invokes Go templating. Preserve OS/data branches and includes from
  `.chezmoitemplates/`; render templates before checking their shell syntax.
- Hook names control timing: `run_` runs each apply, `run_once_` tracks script
  content, `run_onchange_` tracks rendered changes, and `after_` runs after files.
- Lua style comes from `stylua.toml`: two spaces, width 80, single-quote
  preference. `.luarc.json` supplies host globals and diagnostic settings.
- Keep repository-only guidance excluded by target path in `.chezmoiignore`.

## ANTI-PATTERNS

- Do not treat `.aider-desk/tasks/` worktrees, `.codegraph/`, caches, or local
  snapshot directories as the canonical configuration tree.
- Do not run `install.sh`, apply hooks, or `chezmoi apply` as validation. These
  install tools, update links/profiles, and can restart terminals. Host application
  needs user authorization; a request to edit source alone does not authorize it.
- Do not nest `chezmoi apply` inside an active apply: the SSH-switch hook documents
  a persistent-state lock deadlock and uses a deferred second apply.
- Do not import credentials, machine-specific trust paths, or agent runtime state
  into source/config examples. The `private_` prefix controls mode, not encryption.
- Do not track Obsidian notes, attachments, or `Main/Home.md`; selected settings,
  templates, local plugin code, and `_bases/` are the managed source.
- Agent rules and `SKILL.md` files under AiderDesk are configuration payloads.
  Their task-specific workflows are not automatically rules for this repository.

## COMMANDS

Run from the repository root; choose concrete targets for inspection:

```sh
chezmoi --source "$PWD" source-path
chezmoi --source "$PWD" target-path private_dot_config/exact_zsh/dot_zshrc
chezmoi --source "$PWD" --refresh-externals=never managed --include files --path-style source-relative
chezmoi --source "$PWD" --refresh-externals=never --use-builtin-diff diff ~/.config/zsh/.zshrc
git diff --check
```

There is no root build, CI workflow, or repository-wide test runner. Choose
syntax checks for the actual interpreter and scoped tests where present. The
`shellcheck-all` helper scans host paths, not this source tree. The only named
unit-test module is under `private_dot_config/exact_aider-desk/exact_skills/shiki-plan/scripts/`.

## LOCAL AIDERDESK TRANSPORT

Use the fixed-host wrapper for REST operations at `http://127.0.0.1:24337/api`:

```text
/Users/kareemh/.codex/bin/aiderdesk-api METHOD /endpoint [--query NAME=VALUE]... [--json JSON | --json-stdin] [--max-time SECONDS]
```

Use it instead of raw curl. A wrapper failure is REST evidence; a raw sandboxed
curl failure is not evidence that AiderDesk is unavailable. Transport access
does not grant authority to mutate AiderDesk state or dispatch work.

## NOTES

- The source inventory is 551 tracked files across 213 directories at generation;
  ignored task worktrees are excluded. Recompute counts when structure matters.
- Older local path guides and `docs/neovim-plugins.md` include stale paths/options;
  verify against current source and `chezmoi target-path` before following them.
