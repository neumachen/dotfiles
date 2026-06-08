---
name: shiki-project-discovery
description: "Structured first-pass discovery of an unfamiliar repository. Use before planning, before proposing rule changes, and before any cross-cutting refactor to ground decisions in observed reality instead of assumptions."
license: Apache-2.0
---

# Project Discovery

Structured first-pass discovery of an unfamiliar repository. Produces a short, evidence-based summary the agent can rely on for planning, rule-writing, and risk assessment — instead of pattern-matching from prior projects.

## When to Use

Use this skill when:

- Starting work in a repository the agent has not seen before in the current session
- About to propose new rules or skills for a repository
- About to plan a cross-cutting refactor or any change touching > 3 files
- About to choose a build, test, lint, or format command
- The user asks "what is this repo" or "give me the lay of the land"
- Asked to onboard, audit, or review a repository

Do not use when:

- A focused single-file edit is already well-scoped
- The repository's purpose, stack, and conventions are already clearly established in the current session
- The user has explicitly provided the discovery summary already

## Mode Declaration

**SHIKI MODE: Discovery**
Mode: analysis
Purpose: Building a grounded mental model of the repository before any planning or implementation
Implementation: BLOCKED — no source files are modified; only inspection commands and a written discovery summary

## Rules

### Rule: Ground every claim in observed files

**When:** Producing any claim about the repository (purpose, stack, conventions)

**Then:** Cite the file or command that supports the claim

**Examples:**
- "Go module, single binary" → cite `go.mod` and `cmd/<name>/main.go`
- "Phoenix application" → cite `mix.exs` deps and `lib/<app>_web/`
- "Uses Just as task runner" → cite `justfile` at repo root
- "No CI configured" → cite absence of `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/`

**Never:** Infer the stack from directory names alone (e.g. "has `bin/`, must be Rails"). Read manifests.

### Rule: Detect manifests before running commands

**When:** About to suggest a build/test/lint/format command

**Then:** Detect the manifest first and use its convention

**Manifest detection order:**

| Manifest                | Language / framework        | Common commands                          |
| ----------------------- | --------------------------- | ---------------------------------------- |
| `go.mod`                | Go                          | `go build`, `go test ./...`, `golangci-lint run` |
| `package.json`          | Node.js / TypeScript        | check `scripts` field for `build`, `test`, `lint` |
| `pnpm-lock.yaml`        | pnpm                        | prefer `pnpm` over `npm` / `yarn`        |
| `yarn.lock`             | Yarn                        | prefer `yarn` over `npm`                 |
| `mix.exs`               | Elixir / Phoenix            | `mix compile`, `mix test`, `mix format`  |
| `pyproject.toml`        | Python (modern)             | check `[tool.*]` sections for poetry, hatch, uv |
| `requirements*.txt`     | Python (legacy)             | `pip install -r`                         |
| `Cargo.toml`            | Rust                        | `cargo build`, `cargo test`, `cargo fmt` |
| `Gemfile`               | Ruby                        | `bundle install`, `bundle exec rspec`    |
| `*.gemspec`             | Ruby gem                    | gem build / push semantics               |
| `*.csproj` / `*.sln`    | .NET                        | `dotnet build`, `dotnet test`            |
| `pubspec.yaml`          | Dart / Flutter              | `dart` / `flutter` commands              |
| `composer.json`         | PHP                         | `composer install`                       |
| `*.tf` / `*.tfvars`     | Terraform                   | `terraform fmt`, `terraform validate`    |
| `Chart.yaml`            | Helm chart                  | `helm lint`, `helm template`             |
| `Dockerfile`            | container image             | `docker build`, validate with `hadolint` |
| `flake.nix` / `shell.nix` | Nix                       | `nix flake check`, `nix develop`         |

**Wrapper takes precedence:** When the repo ships a `Makefile`, `Taskfile.yml`, `justfile`, or `scripts/` directory, prefer its commands over invoking the underlying toolchain directly. The wrapper encodes the project's own conventions (flags, environment, ordering).

**Never:** Guess a stack from one signal. Multiple repos ship a `Dockerfile` without being primarily a container project.

### Rule: Identify risk areas explicitly

**When:** Producing the discovery summary

**Then:** Enumerate risk areas before any change is proposed

**Risk categories to surface:**

- **Secret-bearing files:** `.env*`, `private_*` (chezmoi), `*.tfvars`, `*.pem`, `id_*`, `*credentials*`, `*.kdbx`, `*.gpg`, `*.age`
- **Secrets-manager hooks:** references to `op` (1Password), `vault`, `aws-vault`, `keepassxc`, `gopass`, `sops`
- **Stateful scripts:** `run_*` chezmoi scripts, migration files, seed scripts, `bootstrap.sh`, `install.sh`, anything under `.chezmoiscripts/`
- **CI / deploy entry points:** `.github/workflows/`, `.gitlab-ci.yml`, `Procfile`, `fly.toml`, `render.yaml`, `vercel.json`, `netlify.toml`
- **Database / data fixtures:** any non-empty `db/`, `migrations/`, `seeds/`, `fixtures/`, `priv/repo/migrations/`
- **External integrations under test:** mocked / stubbed services in `test/`, `spec/`, `__mocks__/`
- **Live config endpoints:** anything that on import or on first run reaches over the network (telemetry, license check, auto-update)

**Surface even if not modifying them.** A risk area that exists but is out of scope is information the user needs for planning.

### Rule: Inventory existing rule coverage

**When:** Producing the discovery summary in a repo that has agent rules

**Then:** List the rule files and a one-line summary of each

**Where to look:**
- `private_dot_config/exact_aider-desk/exact_rules/` (this repo's pattern)
- `.aider-desk/rules/`, `.aider-desk/exact_rules/`
- `.cursor/rules/`, `.cursorrules`
- `.github/copilot-instructions.md`
- `AGENTS.md`, `CLAUDE.md`, `AIDER.md`, `.aiderrules`
- `docs/conventions/`, `docs/rules/`, `docs/style/`

**Output format:** filename, the rule's `description` field if present, and the top-level concern.

**Never:** Assume rules cover everything the project does. Compare rules to observed reality.

### Rule: Name the gaps

**When:** Producing the discovery summary

**Then:** Explicitly list things the repo does that no rule, doc, or wrapper covers

**Examples of gaps worth surfacing:**
- "Repo uses Phoenix LiveView extensively but no Elixir/Phoenix-specific rules exist"
- "All scripts use Bash arrays but no shell style rule is present"
- "Migrations follow a non-standard naming pattern not documented anywhere"
- "Repo has a `Makefile` but its targets are not described in README"

Gaps are inputs for the `shiki-project-rules-lifecycle` skill — not requests to fill them now.

## Process

Run discovery as a single linear pass. Do not branch into implementation, planning, or rule-writing until the summary exists.

### Step 1: Repo purpose

1. Read the README (top of file is usually enough; cap at first ~200 lines unless the summary is buried).
2. Read top-level `LICENSE` for the license type (informs allowed copy patterns).
3. List the top-level directory layout with one command (`ls -1` or equivalent).
4. State the repo's purpose in one sentence, grounded in README/manifest evidence.

If the README is missing or empty, state that explicitly — do not invent a purpose.

### Step 2: Stack identification

1. Detect manifests per the table above.
2. For each manifest, note the language version (e.g., `go.mod` directive, `.tool-versions`, `.python-version`, `mise.toml`).
3. For each manifest, note the major framework or library that drives the project (e.g., Phoenix from `mix.exs`, Rails from `Gemfile`, Next.js from `package.json`).
4. Record the list as `(language, framework, version, manifest)` tuples.

### Step 3: Validation commands

In priority order, look for:

1. A wrapper: `Makefile`, `Taskfile.yml`, `justfile`, `scripts/`, `bin/`.
2. Pre-commit hooks: `.pre-commit-config.yaml`, `lefthook.yml`, `husky/`.
3. CI workflows: `.github/workflows/`, `.gitlab-ci.yml`, etc. — they show the canonical build/test/lint invocations.
4. The toolchain's own conventional commands.

For each, extract:
- The build command(s)
- The test command(s)
- The lint command(s)
- The format command(s)

If a wrapper exists, prefer its targets over raw toolchain invocations and say so explicitly in the summary.

### Step 4: Risk areas

1. Glob for the secret-bearing patterns listed in the rule above.
2. Inspect `.chezmoiscripts/`, `scripts/`, `bin/`, `bootstrap*`, `install*`, and any directory matching `migrations`, `seeds`, `fixtures`.
3. List `.github/workflows/`, `.gitlab-ci.yml`, deploy configs.
4. Note any `run_*` chezmoi script names without reading their contents (the names alone are enough to flag).
5. Do not enumerate the contents of any `private_` file or `.env*` — names and existence only.

### Step 5: Existing rule coverage

1. Locate the rules directory if one exists.
2. List filenames.
3. For each filename, extract its `description` front-matter field (no full content quote).
4. Note any rule files that reference toolchains not present in the repo (stale rules).

### Step 6: Produce the summary

Write a single discovery summary block. Keep it short — six bullets, three lines each at most. The summary is for grounding the next step, not for archival.

## Output Format

Produce exactly this structure, in this order:

```markdown
## Discovery — <repo name or path>

**Purpose**
- One sentence, grounded in README/manifest. Cite the file.

**Stack**
- `<language>` <version> — manifest `<path>` (framework `<name>` if any)
- (one bullet per manifest)

**Validation commands**
- Build:  `<command>` (via `<wrapper or toolchain>`)
- Test:   `<command>`
- Lint:   `<command>`
- Format: `<command>`

**Risk areas**
- (one bullet per risk category that exists; omit categories with no findings)

**Existing rule coverage**
- `<filename>` — `<description from front matter>`
- (one bullet per rule file, or "no rules directory found" if absent)

**Gaps**
- (one bullet per observable convention or risk that has no rule, doc, or wrapper coverage)
```

The summary stays in the conversation; do not write it to disk unless the user asks. If asked to persist it, delegate the write to Forge via `subagents---run_task` rather than writing directly (matches the read-only Analyst delegation protocol).

## Examples

### Good

```markdown
## Discovery — github.com/neumachen/dotfiles

**Purpose**
- chezmoi-managed dotfiles for shell, terminal, editor, Git, and AI workbench. Cite: README.md L1-30.

**Stack**
- Shell (POSIX + zsh) — `dot_zshenv.tmpl`, `dot_zshrc.tmpl`
- Lua — `private_dot_config/exact_nvim/` (Neovim config)
- Bash — `dot_local/bin/executable_shiki` (1100+ LOC launcher)
- chezmoi templates — `.chezmoiroot`, `.chezmoitemplates/`
- Docker — `private_dot_config/exact_shiki/shiki.Dockerfile`

**Validation commands**
- Build:  n/a (configuration repo)
- Test:   `bash -n <script>`, `zsh -n <completion>`
- Lint:   `shellcheck`, `stylua`, `luacheck`
- Format: `stylua --check`, `shfmt -d`

**Risk areas**
- `private_*` files everywhere — credentials, signing keys, 1Password agent paths
- `.chezmoiscripts/run_once_*` — install Homebrew, mise, ssh conversion
- `dot_local/bin/executable_shiki` modifies Docker engine state on the host

**Existing rule coverage**
- `DOCKER-01-HOST-ACCESS.mdc` — Docker host engine access rules
- `SHELL-01-POSIX-CONVENTIONS.mdc` — POSIX-first shell style
- `GIT-01-COMMIT-MESSAGES.md` — conventional-commits authoring
- (28 more, all under `private_dot_config/exact_aider-desk/exact_rules/`)

**Gaps**
- No chezmoi-specific rule (path prefixes, `exact_` semantics, apply discipline)
- No Neovim-config rule despite ~40 Lua files
- No skill describing repo discovery for new sessions
```

### Bad

```markdown
## Discovery — some repo

This looks like a Node.js project. It has a package.json so probably uses npm.
You should run `npm install && npm test`. The code is in `src/` and tests in
`test/`. There are some YAML files which might be config or CI.
```

(Cites no files. Guesses npm without checking lockfile. Vague about CI. No risk areas. No rule inventory. No gaps.)

## Postconditions

Before exiting this skill:

- A discovery summary in the format above is in the conversation
- Every claim cites a file, manifest, or command
- Validation commands name the wrapper used (or "no wrapper found, using toolchain default")
- Risk areas are listed by category, not by file dump
- Rule coverage and gaps are explicitly separated

## Success Metrics

- The next planning or implementation step references the summary's stack and validation commands instead of guessing.
- No claim in the summary turns out to be wrong on close inspection of a cited file.
- The gaps list becomes input for `shiki-project-rules-lifecycle` when rule work is appropriate.
