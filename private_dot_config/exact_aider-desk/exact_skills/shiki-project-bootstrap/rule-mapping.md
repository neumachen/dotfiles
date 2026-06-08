# Rule Mapping — Detected Signals to Global Rules

Reference table consumed by `shiki-project-bootstrap`. Maps detected repo signals to global rules in `exact_rules/`. If a signal has a row here, the rule is already covered (Bucket 1). If a signal is observed but has no row, it is a candidate for Bucket 2 (project-local) or Bucket 3 (extension).

The table reflects the rules that actually exist in `exact_rules/`. Re-confirm against `ls exact_rules/` before recommending; do not invent rules.

## Language and runtime

| Detected signal | Global rule (file) | Concern covered |
| --- | --- | --- |
| `go.mod` | `GOLANG-01-CORE-STYLE.mdc` | Go clarity, naming, idiomatic stdlib usage |
| `go.mod` with multiple packages | `GOLANG-02-PACKAGES-AND-API-BOUNDARIES.mdc` | Package layout, import boundaries, exported API |
| `go.mod` with non-trivial error handling | `GOLANG-03-ERROR-CHECKING.mdc` | When to check, wrap, ignore |
| `go.mod` with custom error types or `%w` | `GOLANG-04-ERROR-STYLE.mdc` | Sentinel errors, wrapping, error types |
| `go.mod` and any HTTP server, DB client, or worker | `GOLANG-05-CONTEXT.mdc` | context propagation, cancellation, deadlines |
| `go.mod` with goroutines / channels / `errgroup` | `GOLANG-06-CONCURRENCY-AND-RESOURCES.mdc` | Goroutines, channels, defer |
| `.golangci.yml` or `gofmt` in CI | `GOLANG-07-STATIC-ANALYSIS-AND-FORMATTING.mdc` | gofmt, go vet, golangci-lint |
| `_test.go` files | `GOLANG-08-TESTING.mdc` | Table-driven tests, testify, t.Helper, t.Cleanup |
| `mix.exs` | `ELIXIR-01-CORE-STYLE.mdc` | Pipelines, pattern matching, with, GenServer, Phoenix |
| `rebar.config` or `.app.src` | `ERLANG-01-CORE-STYLE.mdc` | Pattern matching, processes, supervision, gen_server |
| `Cargo.toml` | `RUST-01-CORE-STYLE.mdc` | Ownership, error handling, traits, async, cargo fmt + clippy |
| `Gemfile` | `RUBY-01-CORE-STYLE.mdc` | Ruby naming, blocks, frozen strings, RuboCop |
| `Gemfile` with `rails` | `RUBY-02-RAILS-CONVENTIONS.mdc` | MVC discipline, concerns, params, services, migrations |
| `Gemfile` with `rails` and any `db/` activity | `RUBY-03-ACTIVERECORD-EFFICIENCY.mdc` | N+1 avoidance, includes vs preload, batching |
| `spec/` directory or `rspec` dependency | `RUBY-04-RSPEC-CONVENTIONS.mdc` | Structure, let, factories, mocking, request/feature/system |
| `package.json` + `tsconfig.json` | `TYPESCRIPT-01-CORE-STYLE.mdc` | Strict mode, type imports, async discipline |
| `package.json` with `react` | `REACT-01-CORE-STYLE.mdc` | Function components, hooks, keys, suspense, server components |
| `*.css`, `*.scss`, or Tailwind config | `CSS-01-CORE-STYLE.mdc` | Custom properties, logical properties, layers, nesting, Tailwind |
| `vite.config.*` | `VITE-01-BUILD-CONVENTIONS.mdc` | Vite env vars, plugins, aliases, optimizeDeps, SSR, library mode |
| `*.lua` files | `LUA-01-CORE-STYLE.mdc` | Lua clarity, naming, idiomatic stdlib |
| `*.lua` files in a Neovim config tree | `LUA-02-NEOVIM-CONVENTIONS.mdc` | Runtime API, plugin authoring, autocommands, keymaps, LSP |
| `*.sh`, `*.bash`, or `*.zsh` files | `SHELL-01-POSIX-CONVENTIONS.mdc` | POSIX-first, bash extensions justified, shellcheck-clean |

## SQL and database

| Detected signal | Global rule (file) | Concern covered |
| --- | --- | --- |
| `*.sql` files or any DB migration directory | `SQL-01-CORE-STYLE.mdc` | Formatting, naming, parameterization, migrations |
| Postgres-specific features (JSONB, RLS, GIN/GiST) | `SQL-02-POSTGRESQL-CONVENTIONS.mdc` | JSONB, indexes, RLS, EXPLAIN ANALYZE, isolation |

## Infrastructure and platform

| Detected signal | Global rule (file) | Concern covered |
| --- | --- | --- |
| `Dockerfile` or `Dockerfile.*` | `DOCKER-02-IMAGE-CONVENTIONS.mdc` | Multi-stage builds, OCI labels, BuildKit, non-root, healthchecks |
| `docker-compose*.yml` / `compose*.yml` | `DOCKER-02-IMAGE-CONVENTIONS.mdc` (companion concerns) | Image build conventions also apply to compose-built images |
| Repo references `--privileged`, host docker socket, or DooD | `DOCKER-01-HOST-ACCESS.mdc` | Prohibited operations and scoping when host engine is reachable |
| Repo produces published container images | `DOCKER-03-SECURITY-AND-SUPPLY-CHAIN.mdc` | SBOMs, scanning, signing, provenance, distroless, digest pinning |
| `Chart.yaml` | `HELM-01-CHART-CONVENTIONS.mdc` | Chart.yaml, values, templates, hooks, library charts |
| `*.yaml` with k8s `apiVersion` / `kind` | `KUBERNETES-01-MANIFEST-CONVENTIONS.mdc` | apiVersion pinning, labels, probes, security, kustomize |
| `*.tf`, `*.tfvars`, `terraform/` | `TERRAFORM-01-CORE-STYLE.mdc` | Module structure, state, providers, secrets |
| `.github/workflows/*.yml` | `GITHUB-01-ACTIONS-COMPOSITION.mdc` | Workflows as entry points, reusable workflows, composite actions |

## Cross-cutting

| Detected signal | Global rule (file) | Concern covered |
| --- | --- | --- |
| Any repo (always) | `GIT-01-COMMIT-MESSAGES.md` | Conventional commits authoring |
| Any repo with secrets, input handling, or auth flow | `SECURITY-01-SECRETS-AND-INPUTS.md` | Secret management, input validation, parameterized queries |

## Signals that have NO matching global rule

When discovery surfaces any of the following, the rule is **not** in `exact_rules/` yet. Bucket assignment depends on scope:

- Repo-specific mission, domain glossary, or feature set → Bucket 2 (`00-project-mission.md`)
- Single-repo deviation from a global rule's defaults → Bucket 2 (note the deviation explicitly)
- A behavior that should be enforced at tool-call time → Bucket 3 (extension)
- A genuinely cross-project pattern not yet in `exact_rules/` → out of scope for bootstrap; use `shiki-write-rule` to add it to the global library

## Update protocol

This table is authored against the `exact_rules/` directory at the time of writing. When global rules are added or removed:

1. Re-list `exact_rules/`.
2. Add or remove rows here to match.
3. Update the row's signal description if the rule's scope has shifted.

Do not let this table drift from the actual directory. A row that points to a non-existent file is worse than no row at all — it makes the bootstrap recommend something the user cannot apply.
