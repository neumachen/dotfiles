#!/usr/bin/env bash
# ============================================================================
# entrypoint.sh — Preflight gate for shiki (extended AiderDesk image).
#
# Checks:
#   1. `git` is installed and on PATH
#   2. /etc/xdg/git/config resolves a non-empty user.name and user.email
#      (these come from the mounted identity file at /etc/xdg/git/identity —
#      see compose.template.yaml `SHIKI_GIT_IDENTITY`)
#   3. If the resolved git config declares a user.signingkey:
#      a. SSH_AUTH_SOCK is set and points to a live agent socket
#      b. (best-effort) report how many identities the agent holds
#
# Notes:
#   - Identity, signing key, and per-project profile routing live entirely
#     in the mounted /etc/xdg/git/identity file. This script no longer
#     generates git config from env vars.
#   - All bind mounts (project dir, AiderDesk config, SSH agent socket,
#     /etc/xdg/git/identity) are the caller's responsibility.
# ============================================================================
set -euo pipefail

errors=0

# ── Check: git binary ──────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
  echo "FATAL: 'git' binary not found on PATH." >&2
  errors=$((errors + 1))
else
  echo "✓ git      $(git --version)"
fi

# Abort early if git itself is missing — every check below depends on it.
if [ "${errors}" -gt 0 ]; then
  echo "" >&2
  echo "Startup aborted — ${errors} preflight check(s) failed." >&2
  exit 1
fi

# ── Resolve identity from the layered XDG git config ───────────────────
# /etc/xdg/git/config (baked) ends with `[include] path = /etc/xdg/git/identity`,
# so these queries reflect the mounted identity file.
git_user_name="$(git config --get user.name || true)"
git_user_email="$(git config --get user.email || true)"
git_signing_key="$(git config --get user.signingkey || true)"

if [ -z "${git_user_name}" ] || [ -z "${git_user_email}" ]; then
  echo "FATAL: git user.name and/or user.email are not configured." >&2
  echo "       The container expects an identity file mounted at" >&2
  echo "       /etc/xdg/git/identity (see SHIKI_GIT_IDENTITY in" >&2
  echo "       compose.template.yaml; default: ~/.config/git/profile)." >&2
  echo "       Resolved: user.name='${git_user_name}' user.email='${git_user_email}'" >&2
  errors=$((errors + 1))
fi

if [ "${errors}" -gt 0 ]; then
  echo "" >&2
  echo "Startup aborted — ${errors} preflight check(s) failed." >&2
  exit 1
fi

echo "✓ ident    ${git_user_name} <${git_user_email}>"

# ── Check: SSH agent (only if signing is configured) ──────────────────
if [ -n "${git_signing_key}" ]; then
  echo "✓ sign     user.signingkey set; container signs via SSH_AUTH_SOCK"
  echo "  ↳ key    ${git_signing_key:0:40}..."

  if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    echo "FATAL: user.signingkey is set but SSH_AUTH_SOCK is not." >&2
    echo "       Mount the 1Password agent socket via compose:" >&2
    echo "         -v ~/.1password/agent.sock:/run/1password/agent.sock" >&2
    echo "         -e SSH_AUTH_SOCK=/run/1password/agent.sock" >&2
    errors=$((errors + 1))
  elif [ ! -S "${SSH_AUTH_SOCK}" ]; then
    echo "FATAL: SSH_AUTH_SOCK='${SSH_AUTH_SOCK}' is not a socket." >&2
    echo "       Ensure the 1Password SSH agent socket is mounted." >&2
    errors=$((errors + 1))
  else
    if agent_output=$(ssh-add -l 2>&1); then
      key_count=$(echo "${agent_output}" | wc -l)
      echo "  ↳ agent  ${SSH_AUTH_SOCK} (${key_count} identity/ies)"
    elif echo "${agent_output}" | grep -q "no identities"; then
      echo "  ↳ agent  ${SSH_AUTH_SOCK} (no identities yet — 1Password loads on demand)"
    else
      echo "FATAL: SSH agent at ${SSH_AUTH_SOCK} is not responding." >&2
      echo "       ssh-add -l returned: ${agent_output}" >&2
      errors=$((errors + 1))
    fi
  fi
fi

# ── Abort if anything failed ──────────────────────────────────────────
if [ "${errors}" -gt 0 ]; then
  echo "" >&2
  echo "Startup aborted — ${errors} preflight check(s) failed." >&2
  exit 1
fi

echo ""

# ── Install shiki's baseline mise toolchain (gh, jq, fzf, vim, delta) ─
#    /etc/mise/config.toml is baked into the image; the per-session
#    MISE_DATA_DIR bind mount makes installs persistent across container
#    restarts of the same session. Non-fatal — a flaky first install
#    shouldn't block the container; rerun `mise install` interactively
#    if needed. Opt out with SHIKI_SKIP_MISE_INSTALL=1.
if [ "${SHIKI_SKIP_MISE_INSTALL:-0}" != "1" ] && command -v mise >/dev/null 2>&1; then
  echo "→ mise install (system + per-session config)"
  if ! mise install --yes; then
    echo "WARNING: mise install failed; continuing without baseline tools." >&2
    echo "         Re-run \`mise install\` inside the container when ready." >&2
  fi
  echo ""
fi

echo "Preflight OK — launching: $*"
exec "$@"
