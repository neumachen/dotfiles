#!/usr/bin/env bash
# ============================================================================
# entrypoint.sh — Preflight gate for shiki (extended AiderDesk image).
#
# Checks:
#   1. `git` is installed and on PATH
#   2. /etc/xdg/git/config resolves a non-empty user.name and user.email
#      (these come from the sanitized identity at /run/shiki/git-identity,
#      derived from the read-only mount at /etc/xdg/git/identity — see
#      compose.template.yaml `SHIKI_GIT_IDENTITY`)
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
#   - Before any git config query runs, the mounted identity is sanitized
#     into a writable copy so host-only `[gpg "ssh"]` keys (e.g. macOS
#     op-ssh-sign program path, host allowed_signers path) cannot break
#     in-container signing. See sanitize_git_identity() below.
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

# ── Sanitize the mounted git identity ──────────────────────────────────
# The read-only bind at /etc/xdg/git/identity comes from the host's
# chezmoi-rendered ~/.config/git/profile. On macOS hosts using 1Password
# SSH signing it declares:
#
#   [gpg "ssh"]
#     program = /Applications/1Password.app/Contents/MacOS/op-ssh-sign
#     allowedSignersFile = ~/.config/git/allowed_signers
#
# Neither value is valid inside the container:
#   - op-ssh-sign is a macOS binary, not installed in this image.
#   - The allowed_signers path is host-relative and unused here
#     (verification happens on the host).
#
# We copy the identity to a writable path and unset only the host-only
# `[gpg "ssh"]` keys, leaving the rest of [user]/[gpg]/[commit]/[tag]
# untouched. After this, git falls back to its compiled-in default
# signer (ssh-keygen), which talks to SSH_AUTH_SOCK -> the mounted
# 1Password agent socket.
#
# Strategy: remove the keys outright rather than overriding with empty
# values. Git treats `program =` (empty) as "exec the empty string" and
# fails with `error: cannot run : No such file or directory`. Removing
# the key is the only way to get the documented default behavior.
sanitize_git_identity() {
  local src="/etc/xdg/git/identity"
  local dst="/run/shiki/git-identity"

  mkdir -p "$(dirname "${dst}")"

  if [ ! -e "${src}" ]; then
    # No identity mounted; write an empty file so the [include] in the
    # baked config still resolves and the user.name/email check below
    # emits a clear FATAL rather than an opaque "missing file" warning.
    : >"${dst}"
    return 0
  fi

  cp "${src}" "${dst}"
  chmod u+w "${dst}"

  # Remove host-only program path unless it's already `ssh-keygen` (in
  # which case the value is valid both on the host and in-container).
  local program
  program="$(git config --file "${dst}" --get gpg.ssh.program || true)"
  if [ -n "${program}" ] && [ "${program}" != "ssh-keygen" ]; then
    echo "→ identity sanitize: drop gpg.ssh.program=${program}"
    # --unset-all tolerates duplicate keys; --unset would error if more
    # than one is present.
    git config --file "${dst}" --unset-all gpg.ssh.program || true
    # `git config --unset` can leave an empty `[gpg "ssh"]` section
    # behind, which is harmless but noisy. Best-effort cleanup.
    git config --file "${dst}" --remove-section 'gpg "ssh"' 2>/dev/null || true
  fi

  # allowedSignersFile is only used by signature verification, which we
  # don't do in-container. Drop it unconditionally so a host-relative
  # path can never trip up future verify-style commands.
  if git config --file "${dst}" --get gpg.ssh.allowedSignersFile >/dev/null 2>&1; then
    echo "→ identity sanitize: drop gpg.ssh.allowedSignersFile"
    git config --file "${dst}" --unset-all gpg.ssh.allowedSignersFile || true
    git config --file "${dst}" --remove-section 'gpg "ssh"' 2>/dev/null || true
  fi
}

sanitize_git_identity

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

# ── Seed AiderDesk's disabled-extensions list ─────────────────────────
# All extensions are baked into the image, but some are disabled by
# default via AiderDesk's settings (settings.extensions.disabled in
# <data-dir>/config.json). The default list comes from the image as
# SHIKI_EXTENSIONS_DISABLED (built from AIDER_DESK_EXTENSIONS_DISABLED);
# override it at runtime by setting SHIKI_EXTENSIONS_DISABLED, or skip
# seeding entirely with SHIKI_SKIP_EXTENSION_DISABLE=1.
#
# The merge is idempotent: it unions the requested IDs into any existing
# disabled list and preserves all other settings, so the defaults are
# re-asserted on every start without clobbering unrelated config. We use
# node (the AiderDesk runtime, always present) rather than jq, which is
# shipped via mise and may not be installed yet at this point.
if [ "${SHIKI_SKIP_EXTENSION_DISABLE:-0}" != "1" ] && [ -n "${SHIKI_EXTENSIONS_DISABLED:-}" ]; then
  config_file="${AIDER_DESK_DATA_DIR:-/app/state}/config.json"
  echo "→ seed disabled extensions into ${config_file}"
  mkdir -p "$(dirname "${config_file}")"
  if ! SHIKI_CONFIG_FILE="${config_file}" node -e '
    const fs = require("fs");
    const file = process.env.SHIKI_CONFIG_FILE;
    const ids = (process.env.SHIKI_EXTENSIONS_DISABLED || "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
    if (ids.length === 0) process.exit(0);
    let data = {};
    try {
      data = JSON.parse(fs.readFileSync(file, "utf8"));
    } catch (err) {
      if (err.code !== "ENOENT") {
        console.error("  skipping seed: cannot parse " + file + ": " + err.message);
        process.exit(0);
      }
    }
    if (!data || typeof data !== "object") data = {};
    if (!data.settings || typeof data.settings !== "object") data.settings = {};
    const ext = (data.settings.extensions && typeof data.settings.extensions === "object")
      ? data.settings.extensions
      : {};
    const current = Array.isArray(ext.disabled) ? ext.disabled : [];
    ext.disabled = Array.from(new Set([...current, ...ids]));
    if (!Array.isArray(ext.repositories)) ext.repositories = [];
    data.settings.extensions = ext;
    const tmp = file + ".tmp";
    fs.writeFileSync(tmp, JSON.stringify(data, null, 2));
    fs.renameSync(tmp, file);
    console.log("  disabled: " + ext.disabled.join(", "));
  '; then
    echo "WARNING: failed to seed disabled extensions; continuing." >&2
  fi
  echo ""
fi

echo "Preflight OK — launching: $*"
exec "$@"
