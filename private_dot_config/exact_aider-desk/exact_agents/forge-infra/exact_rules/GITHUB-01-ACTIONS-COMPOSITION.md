# GitHub Actions Rule: Composition

GitHub Actions has three composition primitives. Use them in their lanes — do not mix.

## The three layers

| Layer | File location | Purpose | Triggered by |
|---|---|---|---|
| **Workflow** (entry point) | `.github/workflows/<name>.yml` | Wires triggers (`on:`), permissions, concurrency. Delegates job logic. | `push`, `pull_request`, `schedule`, `workflow_dispatch`, etc. |
| **Reusable workflow** | `.github/workflows/_reusable-<name>.yml` | Multi-job orchestration that more than one entry point needs. | `workflow_call` from another workflow. |
| **Composite action** | `.github/actions/<name>/action.yml` | A single reusable *step*. The lowest layer. | `uses:` from a job step. |

Hard rules:

- **Entry-point workflows contain triggers and `uses:` calls. They do not contain job logic.** If you see more than ~5 inline `run:` steps in an entry-point workflow, the job logic belongs in a composite action or a reusable workflow.
- **Reusable workflows orchestrate multi-job flows.** Build → test → publish. They have their own `permissions`, `concurrency`, and `secrets:` block. They never call themselves.
- **Composite actions are for single-step reuse.** "Set up the toolchain," "publish coverage," "build the container image." They cannot call other workflows.

## Naming

Underscore prefix marks reusable workflows so the directory listing groups them at the bottom:

```
.github/
├── actions/
│   ├── setup-toolchain/
│   │   └── action.yml
│   ├── publish-coverage/
│   │   └── action.yml
│   └── build-image/
│       └── action.yml
└── workflows/
    ├── ci.yml                       ← entry point: PRs and pushes
    ├── pr-checks.yml                ← entry point: PR-only fast checks
    ├── release.yml                  ← entry point: tags
    ├── scheduled-rescan.yml         ← entry point: cron
    ├── _reusable-build-test.yml     ← reusable workflow
    ├── _reusable-publish-image.yml  ← reusable workflow
    └── _reusable-deploy.yml         ← reusable workflow
```

Names use lower-kebab-case. Entry points are nouns or short verb-objects (`ci`, `release`, `pr-checks`). Reusable workflows are verb-object (`_reusable-build-test`). Composite actions are verbs/object (`setup-toolchain`, `build-image`).

## When to extract

- **Inline step → composite action**: rule of three (third repeat across jobs/workflows), or whenever a single step exceeds ~10 lines of inline `run:`.
- **Job sequence → reusable workflow**: when the same orchestration (build → test → publish) is needed by both `ci.yml` and `release.yml`.
- **One-off**: leave inline. Premature extraction creates a maze of indirection.

## Entry-point workflow shape

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

# Top-level: read-only by default, narrowed per job.
permissions:
  contents: read

# Coalesce duplicate runs on rapid pushes; cancel in-progress runs for non-default refs.
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != format('refs/heads/{0}', github.event.repository.default_branch) }}

jobs:
  build-test:
    uses: ./.github/workflows/_reusable-build-test.yml
    with:
      node-version: '22'
      go-version: '1.23'
    secrets: inherit
```

Rules:

- `name:` at the top — appears in the Actions UI list.
- `on:` declares the triggers. Avoid `on: [push, pull_request]` without branch filters — wastes minutes.
- `permissions:` set at the top level. **Default to `contents: read`** and add jobs-specific permissions narrowly. Do **not** rely on the repo's default permissions; they vary across orgs and may grant too much.
- `concurrency:` declared on every workflow. `cancel-in-progress: true` on PRs is usually right; `false` on the default branch (so a `main`-targeted run finishes even if a new commit lands).
- Body: `uses:` calls to reusable workflows. One job per logical phase.

## Reusable workflow shape

```yaml
# .github/workflows/_reusable-build-test.yml
name: Build and Test (reusable)

on:
  workflow_call:
    inputs:
      node-version:
        description: 'Node.js version (e.g. 22, 22.5, lts/*)'
        required: false
        type: string
        default: '22'
      go-version:
        description: 'Go version (e.g. 1.23, 1.23.x, stable)'
        required: false
        type: string
        default: 'stable'
      run-coverage:
        description: 'Run coverage upload step'
        required: false
        type: boolean
        default: true
    outputs:
      image-digest:
        description: 'Built image digest (when push: true)'
        value: ${{ jobs.build.outputs.digest }}
    secrets:
      codecov-token:
        description: 'Codecov upload token'
        required: false

# Reusable workflows get their own permissions block.
permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      digest: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-toolchain
        with:
          node-version: ${{ inputs.node-version }}
          go-version: ${{ inputs.go-version }}
      - id: build
        run: make build

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-toolchain
        with:
          node-version: ${{ inputs.node-version }}
          go-version: ${{ inputs.go-version }}
      - run: make test
      - if: ${{ inputs.run-coverage }}
        uses: ./.github/actions/publish-coverage
        with:
          token: ${{ secrets.codecov-token }}
```

Rules:

- Every `inputs:` declared with `description`, `required`, `type`, and (if `required: false`) `default`. **No undocumented inputs.**
- Every `outputs:` declared with `description` and a `value:` mapping to a job output.
- Every `secrets:` declared explicitly with `description` and `required`. **Avoid `secrets: inherit` in entry-point workflows unless the reusable workflow's secret needs are clearly documented in its `on.workflow_call.secrets` block.**
- The reusable workflow's `permissions:` block sets its own ceiling. The caller cannot expand it.
- `uses: ./...` paths inside the same repo — never use `org/repo/.github/workflows/...@ref` for repo-local reuse (forces a checkout for the reusable workflow itself).

## Composite action shape

```yaml
# .github/actions/setup-toolchain/action.yml
name: Setup Toolchain
description: 'Install Node, Go, and project tooling for build/test jobs.'

inputs:
  node-version:
    description: 'Node.js version'
    required: false
    default: '22'
  go-version:
    description: 'Go version'
    required: false
    default: 'stable'

outputs:
  go-cache-path:
    description: 'Resolved Go build cache path'
    value: ${{ steps.go.outputs.cache-path }}

runs:
  using: composite
  steps:
    - id: node
      uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020   # v4.4.0
      with:
        node-version: ${{ inputs.node-version }}
        cache: npm

    - id: go
      uses: actions/setup-go@0aaccfd150d50ccaeb58ebd88d36e91967a5f35b   # v5.4.0
      with:
        go-version: ${{ inputs.go-version }}
        cache: true

    - name: Install repo tools
      shell: bash
      run: |
        set -euo pipefail
        npm ci
        go mod download
```

Rules:

- `using: composite` (not `node20`/`node22`/`docker` — those are for marketplace actions, not project-local).
- Every `inputs:` declared with `description`, `required`, and `default` (when `required: false`).
- Every step that runs shell explicitly declares `shell:` (`bash`, `sh`, `pwsh`). No implicit shell.
- **Pin nested actions by full SHA.** Tag-pinning (`actions/checkout@v4`) lets the tag's underlying SHA shift; SHA-pinning is immutable. Comment the human-readable tag next to it.
- Composite actions can't have their own `permissions:` block. They inherit the calling job's permissions.

## Pinning by SHA

For any third-party action (anything not `actions/*` or your own org), pin by SHA:

```yaml
# Good
- uses: docker/build-push-action@2634353a8443c66c9f04ce4ed3f4b3e8f9fd4f97   # v6.18.0
  with: ...

# Bad
- uses: docker/build-push-action@v6
```

`actions/*` and your own org's actions are owned by parties you already trust, so tag-pinning (`actions/checkout@v4`) is acceptable. For everything else, SHA-pin. Dependabot can update SHA pins automatically.

## Permissions

Set the minimum needed per job. Common patterns:

```yaml
# Read-only (the default we recommend at top level):
permissions:
  contents: read

# Pushing to GHCR:
permissions:
  contents: read
  packages: write

# Keyless cosign signing via OIDC:
permissions:
  contents: read
  id-token: write
  packages: write

# Commenting on a PR:
permissions:
  contents: read
  pull-requests: write
```

- **Top-level workflow** declares the union of what its jobs need.
- **Individual jobs** can narrow further but cannot expand.
- **Reusable workflows** must declare their own — they do not inherit from the caller.
- Avoid `permissions: write-all` and `permissions: read-all`. Be specific.

## Secrets

- Declare every secret a reusable workflow consumes in its `on.workflow_call.secrets:` block.
- `secrets: inherit` is convenient but obscures the contract. Use it only when the called workflow truly needs the full set, and document why in a comment.
- Reference secrets only inside `run:` and `with:`. **Never** in `if:` conditions or job names — they appear in logs.
- Mask sensitive output: `echo "::add-mask::${{ secrets.foo }}"`.

## Concurrency

Every workflow declares it.

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
```

Patterns:

- **PRs**: group by `workflow + head ref`, cancel in progress. Rapid force-pushes don't run 5 jobs in parallel.
- **Main branch**: group by `workflow + ref`, do not cancel. Want every commit's build to complete.
- **Release**: group by `workflow + tag`, do not cancel. Releases are too expensive to abort.
- **Deploy**: group by `workflow + environment`, do not cancel; queue.

## Triggers — the costly footguns

- `pull_request` runs on PRs from forks with reduced permissions. Safe by default.
- `pull_request_target` runs with the **target** repo's permissions and secrets. Used for "auto-comment on PR" workflows — and abused for "run tests with secrets on every PR including forks," which is a remote-code-execution vector. **Default: do not use `pull_request_target`.** If you must, never check out the PR's HEAD in the same job that has access to secrets.
- `workflow_run` triggers on another workflow's completion. Useful for "after CI passes, deploy." Beware: the triggered workflow gets the default branch's permissions, not the PR's.
- `schedule: cron:` uses UTC and may be delayed by up to ~30 min during peak load. Don't depend on exact timing.
- `workflow_dispatch` for manual triggers. Always declare `inputs:` even if empty — it documents intent.

## Caching

- Use the framework actions' built-in `cache:` input where available (`actions/setup-node`, `actions/setup-go`, `actions/setup-python`).
- For custom caches, use `actions/cache@<sha>` with a stable key + restore-keys fallback:
  ```yaml
  - uses: actions/cache@<sha>   # v4.x
    with:
      path: ~/.cargo/registry
      key: cargo-${{ runner.os }}-${{ hashFiles('**/Cargo.lock') }}
      restore-keys: |
        cargo-${{ runner.os }}-
  ```
- Cache keys are immutable per repo. Bump them by including the file hash; never reuse a key with different contents.

## `runs-on`

- `ubuntu-latest` is the default — currently Ubuntu 24.04. **Pin** when reproducibility matters: `ubuntu-24.04`.
- Self-hosted runners need their own labels: `runs-on: [self-hosted, linux, x64, my-pool]`. Treat self-hosted as part of your security perimeter — they run your code.
- Avoid `windows-latest` and `macos-latest` unless the build genuinely needs them — they're slower and more expensive.

## Marketplace actions vs `run:` scripts

- Prefer marketplace actions only for genuinely complex operations (`docker/build-push-action`, `actions/setup-node`).
- For simple work (`mkdir`, `tar`, `aws s3 cp`), an inline `run:` step is clearer and has fewer moving parts.
- Wrap repeated `run:` invocations into a composite action once they're stable. Don't extract pre-emptively.

## Anti-patterns

- One mega-workflow with 20 jobs and inline `run:` blocks for everything. Split into entry point + reusable workflows.
- Identical `setup-node` + `setup-go` steps duplicated across five jobs. Extract a composite action.
- Tag-pinning third-party actions. SHA-pin.
- `permissions: write-all` at the top level "just in case."
- `secrets: inherit` everywhere; the contract disappears.
- Cross-workflow communication via writing files to `${{ runner.temp }}` and hoping the next job sees them. Use `outputs:` or `actions/upload-artifact`.
- Conditional logic in `if:` that references secrets or arbitrary string interpolation:
  ```yaml
  # Risk: injection if the input contains shell metachars.
  - if: ${{ inputs.branch == 'main' && contains(inputs.tag, '${{ env.X }}') }}
  ```
  Push complex conditions into `run:` scripts with proper quoting.
- Triggering on `push` and `pull_request` for the same code path with no de-duplication. PR runs duplicate push runs from the source branch.

## Examples

### Good — full directory snapshot

`.github/workflows/ci.yml`:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
permissions:
  contents: read
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
jobs:
  build-test:
    uses: ./.github/workflows/_reusable-build-test.yml
    with:
      node-version: '22'
      run-coverage: ${{ github.event_name == 'pull_request' }}
    secrets:
      codecov-token: ${{ secrets.CODECOV_TOKEN }}
```

`.github/workflows/release.yml`:

```yaml
name: Release
on:
  push:
    tags: ['v*.*.*']
permissions:
  contents: read
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false
jobs:
  build-test:
    uses: ./.github/workflows/_reusable-build-test.yml
    with:
      node-version: '22'
      run-coverage: false
  publish:
    needs: build-test
    uses: ./.github/workflows/_reusable-publish-image.yml
    permissions:
      contents: read
      id-token: write
      packages: write
    with:
      image-name: ghcr.io/${{ github.repository }}
      version: ${{ github.ref_name }}
```

### Bad

```yaml
# One workflow, 200 lines of inline run:, write-all perms, tag-pinned third-party actions:
name: CI
on: [push, pull_request, workflow_dispatch]
permissions: write-all
jobs:
  everything:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/build-push-action@v5
      - run: |
          npm install
          npm run build
          npm run test
          docker login -u user -p ${{ secrets.PASSWORD }}
          docker push myimage:latest
          curl ... | sh
          # ... 150 more lines ...
```
