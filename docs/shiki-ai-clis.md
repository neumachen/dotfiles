# Shiki AI coding CLIs

The Shiki container (an extended AiderDesk image, chezmoi-managed under
`private_dot_config/exact_shiki/`) ships with several AI coding CLIs and
documents opt-in installs for others. Runtimes needed by these agents — git,
POSIX shell, ripgrep, Node 26, glibc for node-pty — are already baked into the
image, so no extra system packages are required to add the managed ones.

## Availability matrix

| Tool | Install channel | Status | Notes |
|---|---|---|---|
| Codex (`@openai/codex`) | npm via mise (`conf.d/50-npm.toml`) | Baked | OpenAI Codex CLI; config at `~/.codex/config.toml` (chezmoi `dot_codex/private_config.toml`), `sandbox_mode=workspace-write`, `network_access=false`. |
| OpenCode (`opencode`) | mise registry `aqua:anomalyco/opencode` (`conf.d/10-registry.toml`) | Managed | Prebuilt platform binary; conservative managed config shipped (see below). |
| Crush (`crush`) | mise registry `aqua:charmbracelet/crush` (`conf.d/10-registry.toml`) | Managed | Go standalone binary; hardened via env vars (see below). |
| Qwen Code (`@qwen-code/qwen-code`) | npm via mise (`conf.d/50-npm.toml`) | Optional | Bundles its own ripgrep; uses system git + shell. |
| Gemini CLI (`@google/gemini-cli`) | npm via mise (`conf.d/50-npm.toml`) | Optional | Uses system git/ripgrep/shell if present. If npm install fails because Bun denies postinstall scripts, switch the `conf.d/50-npm.toml` entry to table form with `bun_args = "--trust"`. |
| [Goose](https://github.com/block/goose) | — | Document-only | Rust CLI. Opt-in install shown below. |
| Kiro CLI (`kiro-cli`) | mise registry `aqua:kiro.dev/kiro-cli` | Document-only | Amazon Q CLI rebrand; standalone glibc/musl binary, no Node runtime; uses `KIRO_API_KEY` for headless auth. |
| Cursor CLI (`cursor-agent`) | — | Document-only | No reliable managed install path; not recommended for the managed image. |

**Status key:**

- **Baked** — already present in the image after build.
- **Managed** — installed per-session via `mise install`.
- **Optional** — present in a registry fragment; install runs only if the entry
  is uncommented or added to `~/.config/mise/config.toml`.
- **Document-only** — not in mise registry; manual opt-in steps provided below.

## OpenCode managed config

OpenCode reads `~/.config/opencode/opencode.json`. The chezmoi source is
`private_dot_config/exact_opencode/opencode.json`. Compose bind-mounts it
read-only into the container at `/root/.config/opencode/opencode.json`
(mirroring the Claude `settings.json` pattern).

The shipped conservative policy:

```json
{
  "autoupdate": false,
  "share": "disabled",
  "permission": {
    "edit": "ask",
    "bash": "ask"
  }
}
```

- `autoupdate: false` — version control delegated to mise/the image.
- `share: "disabled"` — no session upload or telemetry.
- `permission.edit: "ask"` and `permission.bash: "ask"` — explicit approval
  required for edits and shell execution.

## Crush hardening

Crush is hardened via environment variables set in `compose.template.yaml`
rather than a `crush.json` file. Crush evaluates `$(...)` command substitutions
in its JSON config at load time — pointing it at an untrusted project-local
`crush.json` is a code-execution risk. The container avoids project-local
config and sets policy via env:

| Env var | Effect |
|---|---|
| `CRUSH_DISABLE_PROVIDER_AUTO_UPDATE=1` | Disable auto-update of provider binaries. |
| `CRUSH_DISABLE_METRICS=1` | Disable Crush's built-in metrics collection. |
| `DO_NOT_TRACK=1` | Crush honors the cross-tool [Do Not Track](https://consoledonottrack.com/) convention. |

> **Warning:** Never point `crush.json` at an untrusted project file. The
> command-substitution behaviour makes any project-local config a potential
> arbitrary-code-execution vector.

## Opt-in installs (document-only tools)

These commands run inside a running container (e.g. via `docker exec`).

### Goose (Rust CLI)

```sh
curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | bash
```

Downloads a prebuilt binary; review before running.
See [Goose on GitHub](https://github.com/block/goose).

### Kiro CLI (Amazon Q rebrand)

```sh
mise use -g kiro-cli@latest
```

Authenticate headless with the `KIRO_API_KEY` environment variable.
See [Kiro](https://kiro.dev).

### Cursor CLI

There is no clean managed install path. If desired, install per Cursor's own
instructions at [cursor.com](https://cursor.com). Not recommended for the
managed image.

## Verify / smoke-test

After `chezmoi apply` and `shiki --rebuild`, start a session and check tools
resolve:

```sh
shiki -n tool-smoke
docker exec -it tool-smoke bash -lc 'mise install --yes && command -v git rg opencode crush && opencode --version && crush --version'
```

The user runs `chezmoi apply` / `shiki --rebuild` themselves.

## Adding more tools

Managed CLIs are added by editing the mise fragments under
`private_dot_config/exact_shiki/mise/conf.d/` — registry-resolvable tools go in
`10-registry.toml`, npm globals in `50-npm.toml` — then run `chezmoi apply` and
`shiki --rebuild`.
