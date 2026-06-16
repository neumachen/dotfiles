# Shiki log observability

A shared, containerized Loki + Grafana + Alloy + Dozzle stack that surfaces the
rich structured logs AiderDesk already writes to disk inside each `shiki`
session, but which are otherwise hidden behind very terse stdout lines.

## The problem

The `shiki` workbench runs AiderDesk inside a per-session container. When the
LLM backend fails, AiderDesk's stdout shows something like:

```
Error during iteration: Internal server error {"type":"api_error"}
```

That terseness is a property of AiderDesk's Winston console transport — it uses
`format.simple()` without `format.errors({ stack: true })`, so anything richer
than `message` is dropped from stdout.

The full structured error — `name`, `type`, `isRetryable`, `requestBodyValues`,
`taskId`, stack — is, however, written to JSON log files on the host under:

```
~/.local/share/aider-desk/<session>/data/logs/
  error-%DATE%.log
  combined-%DATE%.log
```

The files are date-rotated and unused by default. This stack makes them
queryable.

## The stack

Everything runs in a dedicated compose project, `shiki-observability`, separate
from any session container. Nothing runs natively on the host.

| Service | Image | Role |
|---|---|---|
| Alloy | `grafana/alloy` | Tails `~/.local/share/aider-desk` (whole data root, all sessions) read-only, parses each JSON line, ships to Loki |
| Loki | `grafana/loki` | Log store and index, 30-day retention, persistent volume |
| Grafana | `grafana/grafana` | Query UI, auto-provisioned Loki datasource, starter AiderDesk dashboard, persistent volume |
| Dozzle | `amir20/dozzle` | Live raw container-log viewer (host Docker socket, read-only) |

Alloy labels each line with `job=aiderdesk`, `session=<session-id>`,
`stream=error|combined`, and extracts `level`, `type`, `name`, `taskId` from the
JSON payload.

### Files

Chezmoi source → rendered target under `~/.config/shiki/`:

```
private_dot_config/exact_shiki/compose.observability.yaml
private_dot_config/exact_shiki/observability/loki-config.yaml
private_dot_config/exact_shiki/observability/alloy-config.alloy
private_dot_config/exact_shiki/observability/grafana-datasource.yaml
private_dot_config/exact_shiki/observability/grafana-dashboard-provider.yaml
private_dot_config/exact_shiki/observability/grafana-dashboard-aiderdesk.json
```

Launcher integration lives in `dot_local/bin/executable_shiki`.

## Launcher behaviour

The stack is **default-on, opt-out**. On every `shiki` session launch the
launcher idempotently brings the shared `shiki-observability` compose project
up; bring-up is non-fatal and never blocks the session.

| Flag / env | Effect |
|---|---|
| _(none)_ | Bring stack up if not running. Already-running stack is reused. |
| `--no-observability`, `SHIKI_OBSERVABILITY=0` | Skip bring-up. Does **not** stop an already-running stack. |
| `--observability` | Force bring-up. |
| `SHIKI_OBSERVABILITY_BIND=<addr>` | Host bind address for published ports. Default `127.0.0.1`. |

The launch banner prints the Grafana and Dozzle URLs.

## Access and security

Machine-only by default:

| Service | Localhost port | OrbStack DNS |
|---|---|---|
| Grafana | `127.0.0.1:3000` | `http://grafana.shiki-observability.orb.local` |
| Dozzle | `127.0.0.1:8080` | `http://dozzle.shiki-observability.orb.local` |
| Loki | _no host port_ | internal compose network only |
| Alloy | _no host port_ | internal compose network only |

Loki and Alloy ship with **no authentication** — that is why the default
binding is localhost-only. The logs contain prompt, code, and token-context
data; treat the Loki store as confidential.

Dozzle's Docker-socket mount is read-only, but the socket is still the host
engine control plane. Same caution class as the `--docker-host` overlay.

Opt-in LAN exposure: set `SHIKI_OBSERVABILITY_BIND=0.0.0.0`. If you do, enable
Grafana auth and put Loki/Alloy behind something — they remain unauthenticated.

## Usage

Normal launch: nothing to do. Open the URL the banner prints.

Find recent API errors (LogQL):

```logql
{job="aiderdesk"} | json | type="api_error"
```

All error-stream lines for the current sessions:

```logql
{job="aiderdesk", stream="error"}
```

Filter by task:

```logql
{job="aiderdesk"} | json | taskId="<task-id>"
```

Tail raw container output without Grafana: open Dozzle.

Stop the shared stack:

```sh
docker compose -p shiki-observability down
```

Volumes persist; logs survive a restart and persist across host reboots
(`restart: unless-stopped`).

## Notes and tradeoffs

- **Alloy over syslog-ng.** Alloy is purpose-built for file → Loki, handles log
  rotation natively, has first-class JSON pipeline stages, and lives in the
  same `grafana/*` family as the rest of the stack. syslog-ng's routing power
  is unused when the only sink is Loki.
- **Shared, not per-session.** Deliberate: query history and dashboards
  outlive any one session container.
- **Stdout in the AiderDesk container is unchanged.** Fixing the terse line
  would mean patching the bundled `runner.js`, which is upstream and out of
  scope here. The file logs — now surfaced through Loki and Grafana — already
  carry the full detail.
