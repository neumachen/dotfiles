#!/usr/bin/env bash
#
# install.sh — resumable, converging bootstrap for the neumachen/dotfiles repo.
#
# This file is listed in .chezmoiignore, so it is never deployed; it only runs
# from the clone (or from a curl | sh one-liner).
#
# Contract
# --------
# * NEVER hard-exit because a prerequisite is missing. Missing prerequisites are
#   recorded as *deferred* and the installer keeps going, then reports them at
#   the end. The only non-zero exits are:
#     - not macOS and not Linux                                    (exit 1)
#     - chezmoi is absent and there is no curl, no wget and no brew
#       to fetch it                                                (exit 1)
#     - bash is absent (this script is bash, not POSIX sh)         (exit 2)
#     - the script was piped into a non-bash shell and could not be
#       re-fetched, or what was fetched failed the sanity check    (exit 2)
#     - interrupted                                                (exit 130)
#   The exit-2 cases are *invocation/transport* failures, not missing
#   prerequisites: there is no script body left to run, so continuing is
#   impossible. Every genuine prerequisite (CLT, Xcode, Homebrew, 1Password,
#   mise, ...) is still only ever deferred.
# * NEVER kill or replace the calling shell. The `exec` calls below replace only
#   *this script's own* process image so that it runs under bash; the caller's
#   shell is untouched and regains control when the script exits. chezmoi is
#   deliberately NOT exec'd, so its exit status is captured and the later stages
#   still run.
# * Idempotent and resumable. Re-running on a half-configured machine picks up
#   where it left off, driven by ~/.cache/chezmoi/bootstrap-status.{txt,json}
#   (written by bootstrap-status, dot_local/bin/executable_bootstrap-status).
# * bash 3.2 compatible (macOS /bin/bash): indexed arrays only, no associative
#   arrays, no ${x,,}, no mapfile.

# Pinned contract — the README documents these exact values and forms.
# DOTFILES_INSTALL_URL overrides where the piped/`sh -c` form re-fetches from, so
# a fork or a feature branch can be tested without editing this file.
INSTALL_URL="${DOTFILES_INSTALL_URL:-https://raw.githubusercontent.com/neumachen/dotfiles/main/install.sh}"
# A string unique to this script, used to confirm that a candidate file really is
# install.sh rather than something that happens to share its name — a CDN 404
# page, a captive-portal interstitial, or a different script entirely.
# `stage5_postflight` is a function *defined near the end of this file*, so
# requiring it also proves the download was not truncated. (A prose marker taken
# from the header comment would pass on a partial download, and could be silently
# broken by an unrelated wording edit.)
SCRIPT_MARKER="stage5_postflight"

# Re-exec under bash when this file was not started by bash. Three invocation
# forms have to work:
#
#   ./install.sh | bash install.sh   BASH_VERSION is already set; guard skipped.
#   sh install.sh                    $0 is this script -> exec bash on it (A).
#   sh -c "$(curl -fsSL URL)"        $0 is "sh", and the body arrived either via
#   curl -fsSL URL | sh              command substitution or an already-exhausted
#                                    stdin pipe, so there is no file to exec (B).
#
# These `exec` calls replace this script's own process image only — the calling
# shell is untouched and regains control when the script exits.
if [ -z "${BASH_VERSION:-}" ]; then
  if ! command -v bash >/dev/null 2>&1; then
    echo "[ERROR] --- install.sh requires bash; this script is bash, not POSIX sh." >&2
    echo "[ERROR] --- Install bash, then download the installer and run it with bash:" >&2
    echo "[ERROR] ---   curl -fsSL ${INSTALL_URL} -o /tmp/dotfiles-install.sh && bash /tmp/dotfiles-install.sh" >&2
    # exit 2, not 1: this is an invocation/transport failure (there is no
    # interpreter able to run the script body), not a missing prerequisite.
    exit 2
  fi

  # Case A: invoked as `sh /path/to/install.sh`, so $0 is this script. Verify it
  # by CONTENT, not merely by existence: $0 is whatever the caller passed, so a
  # stray file named `sh` (or anything else $0 happens to name) in the current
  # directory must never be exec'd in place of the installer.
  if [ -n "${0:-}" ] && [ -f "$0" ] && [ -r "$0" ] &&
    grep -qF "$SCRIPT_MARKER" "$0" 2>/dev/null; then
    exec bash "$0" "$@"
  fi

  # Case B: piped / `sh -c` invocation. $0 is not this script and stdin is
  # already consumed, so re-fetch to a temp file and exec bash on that.
  # NOTE: the X's must be at the END of the template. BSD/macOS mktemp does not
  # substitute a run of X's that is followed by a suffix: `...XXXXXX.sh` silently
  # creates a file with that literal, predictable name (rc=0) and every later run
  # then fails with "File exists" — so a piped install would work once per machine
  # and never again, besides putting a fixed name in a world-writable directory.
  # Verified: `dotfiles-install.sh.XXXXXX` yields a unique file on dash, bash 3.2
  # and GNU mktemp alike.
  tmp="$(mktemp "${TMPDIR:-/tmp}/dotfiles-install.sh.XXXXXX" 2>/dev/null)" || tmp=""
  if [ -z "$tmp" ]; then
    echo "[ERROR] --- could not create a temp file in ${TMPDIR:-/tmp} to re-fetch install.sh." >&2
    exit 2
  fi

  fetched=0
  if command -v curl >/dev/null 2>&1 && curl -fsSL "$INSTALL_URL" -o "$tmp"; then
    fetched=1
  elif command -v wget >/dev/null 2>&1 && wget -qO "$tmp" "$INSTALL_URL"; then
    fetched=1
  fi
  if [ "$fetched" -ne 1 ]; then
    rm -f "$tmp"
    echo "[ERROR] --- install.sh was piped into a non-bash shell and could not be" >&2
    echo "[ERROR] --- re-fetched from ${INSTALL_URL}." >&2
    echo "[ERROR] --- Download it manually, then run it with bash instead:" >&2
    echo "[ERROR] ---   curl -fsSL ${INSTALL_URL} -o /tmp/dotfiles-install.sh && bash /tmp/dotfiles-install.sh" >&2
    exit 2
  fi

  # Validate BEFORE exec'ing. Three conditions must all hold: the file is
  # non-empty, its first line is a shebang, and it contains a marker unique to
  # this script. A proxy captive portal, a CDN 404 page, a different script or a
  # truncated download must never be executed as shell code.
  first_line=""
  # `read` returns non-zero at EOF-without-a-trailing-newline while still
  # assigning the text it read, so its status is deliberately not treated as a
  # failure; the case statement below is what validates the content.
  IFS= read -r first_line < "$tmp" 2>/dev/null
  case "$first_line" in
    '#!'*) : ;;               # a real shebang — accept
    *)     first_line="" ;;   # anything else fails the check below
  esac
  if [ ! -s "$tmp" ] || [ -z "$first_line" ] || ! grep -qF "$SCRIPT_MARKER" "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    echo "[ERROR] --- what was fetched from ${INSTALL_URL} is not install.sh" >&2
    echo "[ERROR] --- (empty, no shebang on line 1, or missing the content marker);" >&2
    echo "[ERROR] --- refusing to run it." >&2
    echo "[ERROR] --- Download it manually, inspect it, then run it with bash:" >&2
    echo "[ERROR] ---   curl -fsSL ${INSTALL_URL} -o /tmp/dotfiles-install.sh && bash /tmp/dotfiles-install.sh" >&2
    exit 2
  fi

  chmod +x "$tmp"

  # There is no re-fetch loop: the interpreter below is explicitly `bash`, so
  # BASH_VERSION is set on the second pass and this whole guard is skipped.
  #
  # Restore stdin from the controlling terminal when there is one. A piped
  # install leaves stdin as an exhausted pipe, which would make _is_tty false
  # and cause every _ask to silently take its default — exactly when the user
  # most needs to answer (CLT skip, Xcode license, converge-loop Enter/q).
  #
  # Hand the temp path to the re-exec'd child so IT can unlink the file on exit.
  # This process cannot clean up after itself: exec replaces its image, so any
  # trap registered here would never run. Without this hand-off every piped
  # install would leave a dotfiles-install.XXXXXX.sh behind in $TMPDIR.
  DOTFILES_INSTALL_TMPFILE="$tmp"
  export DOTFILES_INSTALL_TMPFILE

  # Detect the controlling terminal by actually trying to OPEN it, not by
  # stat'ing the device node. `[ -r /dev/tty ]` only inspects permission bits and
  # succeeds even when there is no controlling terminal (cron, CI, launchd, a
  # pipe with no tty); the redirect then fails with "cannot open /dev/tty:
  # Device not configured" and the whole install dies. The subshell probe below
  # is the portable way to ask "can I really open it?".
  if (: </dev/tty) 2>/dev/null; then
    exec bash "$tmp" "$@" </dev/tty
  fi
  exec bash "$tmp" "$@"
fi

# Deliberately NOT `set -e`: a converging installer must survive a failing
# prerequisite and still reach the postflight report.
set -uo pipefail

# If this process is the re-exec'd child of a piped / `sh -c` install, the script
# body lives in a temp file created by the parent, which could not clean it up
# (exec replaced the parent's image, so no parent-side trap ever ran). Unlink it
# on exit so a piped install leaves nothing behind in $TMPDIR.
#
# Unlinking a script bash is running is safe: unlink only removes the directory
# entry, the inode survives until the last open descriptor closes, and by the
# time EXIT fires bash has finished reading the file anyway.
#
# The variable is set and exported by the guard above immediately before exec, so
# it is present only in the re-fetched child — never in a clone-based run.
if [ -n "${DOTFILES_INSTALL_TMPFILE:-}" ] && [ -f "${DOTFILES_INSTALL_TMPFILE:-}" ]; then
  trap 'rm -f "${DOTFILES_INSTALL_TMPFILE:-}"' EXIT
fi

REPO="https://github.com/neumachen/dotfiles.git"

_log_info()  { if command -v echo-info  >/dev/null 2>&1; then echo-info  "$@"; else echo "[INFO] --- $*"; fi; }
_log_ok()    { if command -v echo-ok    >/dev/null 2>&1; then echo-ok    "$@"; else echo "[SUCCESS] --- $*"; fi; }
_log_warn()  { if command -v echo-warn  >/dev/null 2>&1; then echo-warn  "$@"; else echo "[WARN] --- $*" >&2; fi; }
_log_err()   { if command -v echo-err   >/dev/null 2>&1; then echo-err   "$@"; else echo "[ERROR] --- $*" >&2; fi; }

# Create required directories before chezmoi runs
# These are needed by various dotfiles and chezmoi itself
# shellcheck disable=SC2329 # invoked indirectly via `_run create_required_dirs`
create_required_dirs() {
  _log_info "Creating required directories..."
  
  # Local bin directories
  mkdir -p "${HOME}/.local/bin"
  mkdir -p "${HOME}/.local/sbin"
  
  # XDG directories
  mkdir -p "${HOME}/.config"
  mkdir -p "${HOME}/.local/share"
  
  # MeinCodex directories (used for notes, code, snippets)
  meincodex_dir="${HOME}/MeinCodex"
  mkdir -p "${meincodex_dir}/Notizen"
  mkdir -p "${meincodex_dir}/Codebasis"
  mkdir -p "${meincodex_dir}/Codeschnipsel"
  
  # Create the dotfiles destination directory structure
  # This matches the sourceDir in .chezmoi.yaml.tmpl
  # Note: github.com and below remain lowercase (actual repo paths)
  mkdir -p "${meincodex_dir}/Codebasis/github.com/neumachen"
}

# ---------------------------------------------------------------------------
# flags and state
# ---------------------------------------------------------------------------

ASSUME_YES=0
REPROMPT=0
MAX_PASSES=5
SKIP_CLT=0
SKIP_XCODE=0
VERBOSE=0
DRY_RUN=0

DEFER_CLT=0
DEFER_XCODE=0
DEFERRED=()

SCRIPT_DIR=""
CHEZMOI=""
STATUS_BIN=""
BUILTIN_GIT_FLAG="--use-builtin-git=auto"
STAGE3_RC=0
CONVERGED="no"

CACHE_DIR="${BOOTSTRAP_STATUS_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/chezmoi}"
STATUS_TXT="${CACHE_DIR}/bootstrap-status.txt"
STATUS_JSON="${CACHE_DIR}/bootstrap-status.json"

# Status document parsed out of bootstrap-status.json (parallel arrays).
S_IDS=()
S_STATES=()
S_MSGS=()

CLT_TIMEOUT="${CLT_TIMEOUT:-900}" # 15 minutes, generous on purpose
CLT_INTERVAL=10

# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------

_have() { command -v "$1" >/dev/null 2>&1; }

_os_name() { uname -s 2>/dev/null; }

_is_darwin() { [ "$(_os_name)" = "Darwin" ]; }

_is_linux() { [ "$(_os_name)" = "Linux" ]; }

_is_tty() { [ -t 0 ] && [ -t 1 ]; }

_banner() {
  printf '\n'
  _log_info "==================== $1 ===================="
}

# Record something the installer could not do. Never fatal.
_defer() {
  _log_warn "deferred: $1"
  DEFERRED+=("$1")
}

# _ask PROMPT y|n — honours --yes and non-interactive stdin by taking the
# default. Returns 0 for yes.
_ask() {
  local prompt="$1"
  local default="$2"
  local reply=""
  local suffix="[y/N]"
  if [ "$default" = "y" ]; then
    suffix="[Y/n]"
  fi
  if [ "$ASSUME_YES" -eq 1 ] || ! _is_tty; then
    if [ "$default" = "y" ]; then
      return 0
    fi
    return 1
  fi
  printf '%s %s ' "$prompt" "$suffix"
  IFS= read -r reply || reply=""
  case "$reply" in
    '')
      if [ "$default" = "y" ]; then return 0; fi
      return 1
      ;;
    [yY] | [yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# _run CMD... — honours --dry-run and --verbose. Never aborts the installer.
_run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] would run: %s\n' "$*"
    return 0
  fi
  if [ "$VERBOSE" -eq 1 ]; then
    printf '  + %s\n' "$*"
  fi
  "$@"
}

_row() { printf '  %-16s %s\n' "$1" "$2"; }

# ---------------------------------------------------------------------------
# interrupt handling
# ---------------------------------------------------------------------------

# shellcheck disable=SC2329 # invoked indirectly, as the INT/TERM trap handler
_on_signal() {
  printf '\n'
  _log_warn "interrupted — re-run install.sh to resume; nothing is broken"
  exit 130
}

trap _on_signal INT TERM

# No background sudo keep-alive is started by this script (unlike
# .chezmoitemplates/script_sudo), so there is nothing to reap on exit. sudo is
# only ever used in the foreground, for the optional Xcode license step.

# ---------------------------------------------------------------------------
# usage
# ---------------------------------------------------------------------------

usage() {
  cat <<'USAGE'
install.sh — resumable, converging bootstrap for the neumachen/dotfiles repo.

Usage:
  1. from a clone:      ./install.sh          (or: bash install.sh, sh install.sh)
USAGE
  # Forms 2 and 3 interpolate $INSTALL_URL, so they cannot live inside the quoted
  # heredoc above. printf keeps every other character literal, so the
  # `$(curl ...)` command substitution and the surrounding quotes are printed
  # verbatim for the user to copy instead of being expanded here. With no
  # DOTFILES_INSTALL_URL override set, the three lines are byte-identical to the
  # invocation block in README.md — keep the two in sync.
  # shellcheck disable=SC2016 # intentional: printing a literal command, not expanding it
  printf '  2. one-liner, piped:  sh -c "$(curl -fsSL %s)"\n' "$INSTALL_URL"
  printf '  3. one-liner, saved:  curl -fsSL %s \\\n' "$INSTALL_URL"
  printf '                          -o /tmp/dotfiles-install.sh && bash /tmp/dotfiles-install.sh\n'
  cat <<'USAGE'

Form 3 is the most robust: it survives a flaky network mid-run and is re-runnable.
The URL serves the `main` branch.

Flags:
  --yes             never prompt; take the default and defer anything ambiguous
  --reprompt        pass --prompt to `chezmoi init` so every prompt*Once value
                    is re-asked. This is the recovery path for a poisoned
                    ~/.config/chezmoi/chezmoi.yaml
  --max-passes N    max `chezmoi apply` passes in the converge loop (default 5;
                    0 skips the loop and goes straight to the report)
  --skip-clt        do not raise or wait for the Command Line Tools dialog
  --skip-xcode      do not ask about full Xcode or its license
  --verbose         pass -v to chezmoi and echo every command before running it
  --dry-run         walk every stage printing what it would do; execute nothing
                    (no mkdir, no downloads, no chezmoi, no brew, no sudo)
  -h, --help        this help

Stages:
  0 preflight (read-only)   1 Command Line Tools gate   2 Xcode + license gate
  3 chezmoi bootstrap       4 converge loop             5 postflight report

A missing prerequisite is never fatal: it is recorded as deferred and the
installer continues, then lists the concrete manual actions at the end.
Re-running install.sh resumes; `bootstrap-status` shows what is outstanding.
USAGE
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --yes) ASSUME_YES=1 ;;
      --reprompt) REPROMPT=1 ;;
      --max-passes)
        if [ "$#" -lt 2 ]; then
          _log_err "--max-passes requires a number"
          exit 2
        fi
        MAX_PASSES="$2"
        shift
        ;;
      --max-passes=*) MAX_PASSES="${1#--max-passes=}" ;;
      --skip-clt) SKIP_CLT=1 ;;
      --skip-xcode) SKIP_XCODE=1 ;;
      --verbose) VERBOSE=1 ;;
      --dry-run) DRY_RUN=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        _log_err "unknown argument: $1"
        usage
        exit 2
        ;;
    esac
    shift
  done

  case "$MAX_PASSES" in
    '' | *[!0-9]*)
      _log_err "--max-passes must be a non-negative integer, got: ${MAX_PASSES}"
      exit 2
      ;;
  esac
}

# ---------------------------------------------------------------------------
# probes
# ---------------------------------------------------------------------------

_clt_ready() {
  _have pkgutil || return 1
  pkgutil --pkg-info=com.apple.pkg.CLTools_Executables >/dev/null 2>&1 || return 1
  _have xcode-select || return 1
  xcode-select -p >/dev/null 2>&1 || return 1
  _have xcrun || return 1
  xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1 || return 1
  return 0
}

_xcode_license_ok() {
  [ -d /Applications/Xcode.app ] || return 1
  _have xcodebuild || return 1
  xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1 || return 1
  _have xcrun || return 1
  xcrun clang --version >/dev/null 2>&1 || return 1
  return 0
}

_op_agent_sock() {
  printf '%s' "${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
}

_find_status_bin() {
  local c=""
  # Prefer the copy in this clone: on a fresh machine chezmoi has not deployed
  # ~/.local/bin/bootstrap-status yet.
  for c in "${SCRIPT_DIR}/dot_local/bin/executable_bootstrap-status" \
    "${HOME}/.local/bin/bootstrap-status"; do
    if [ -f "$c" ]; then
      STATUS_BIN="$c"
      return 0
    fi
  done
  if _have bootstrap-status; then
    STATUS_BIN="$(command -v bootstrap-status)"
    return 0
  fi
  STATUS_BIN=""
  return 0
}

# _status ARGS... — invoke bootstrap-status read-only.
# Under --dry-run it is NOT invoked at all: bootstrap-status internally queries
# brew and chezmoi, and a dry run must execute nothing.
_status() {
  [ -n "$STATUS_BIN" ] || return 1
  if [ "$DRY_RUN" -eq 1 ]; then
    if [ "$#" -gt 0 ]; then
      printf '  [dry-run] would run: bash %s %s\n' "$STATUS_BIN" "$*"
    else
      printf '  [dry-run] would run: bash %s\n' "$STATUS_BIN"
    fi
    return 0
  fi
  bash "$STATUS_BIN" "$@"
}

# Fill S_IDS / S_STATES / S_MSGS from the cached JSON, or from a live
# bootstrap-status run when the cache does not exist yet.
#
# bootstrap-status currently emits one field per line:
#     {
#       "id": "clt",
#       "state": "green",
#       "message": "..."
#     },
# This parser also accepts the compact one-line-per-check form
#     { "id": "clt", "state": "green", "message": "..." },
# so install.sh keeps working against an older or newer deployed
# bootstrap-status. Records are flushed when the next "id" is seen, which keeps
# the three arrays aligned by construction.
_load_status_doc() {
  local json="" line="" id="" st="" msg="" flat="" objs=""
  S_IDS=()
  S_STATES=()
  S_MSGS=()

  if [ -f "$STATUS_JSON" ]; then
    json="$(cat "$STATUS_JSON" 2>/dev/null)"
  elif [ -n "$STATUS_BIN" ]; then
    json="$(_status --json 2>/dev/null)"
  fi
  [ -n "$json" ] || return 1

  # Normalise the layout before the line-based walk below.
  #
  # A valid JSON document never contains a RAW newline inside a string (it would
  # be escaped as \n), so collapsing the document to a single line is lossless.
  # Re-splitting on check-object boundaries then yields exactly one line per
  # check for EVERY emitter layout: minified, one-object-per-line, or one-field-
  # per-line. Without this a minified document parses as a single check (the
  # greedy `.*"id":` in _json_field matches only the last one), which would
  # silently defeat the stall detection in stage4_converge.
  #
  # `[^{}]*` keeps the match inside a single check object — the outer document
  # object contains nested braces and so can never match.
  flat="$(printf '%s' "$json" | tr -d '\n\r')"
  objs="$(printf '%s' "$flat" | grep -o '{[^{}]*"id"[^{}]*}' 2>/dev/null)"
  [ -n "$objs" ] && json="$objs"

  while IFS= read -r line; do
    case "$line" in
      *'"id"'*)
        if [ -n "$id" ] && [ -n "$st" ]; then
          S_IDS+=("$id")
          S_STATES+=("$st")
          S_MSGS+=("$msg")
        fi
        id="$(_json_field "$line" id)"
        st="$(_json_field "$line" state)"
        msg="$(_json_field "$line" message)"
        ;;
      *'"state"'*) st="$(_json_field "$line" state)" ;;
      *'"message"'*) msg="$(_json_field "$line" message)" ;;
    esac
  done <<EOF
$json
EOF

  if [ -n "$id" ] && [ -n "$st" ]; then
    S_IDS+=("$id")
    S_STATES+=("$st")
    S_MSGS+=("$msg")
  fi

  [ "${#S_IDS[@]}" -gt 0 ]
}

# _status_key — semantic comparison key for stall detection: one "id=state"
# line per check, in document order.
#
# D7: there are two independent writers of bootstrap-status.json —
# dot_local/bin/executable_bootstrap-status (authoritative) and the inline
# fallback in .chezmoiscripts/run_after_99-bootstrap-status.sh.tmpl. They agree
# today, but comparing the raw document textually would report spurious
# "progress" the moment either layout drifts (indentation, key order, message
# wording, generated_at, hostname), burning every MAX_PASSES on a machine that
# has actually stalled. Deriving the key from id+state only makes the comparison
# immune to all of that.
#
# Returns non-zero (and prints nothing) when no document could be read, so the
# caller treats it as "no comparison possible" rather than as progress.
# bash 3.2 safe: indexed arrays only, no associative arrays, no ${x,,}.
_status_key() {
  _load_status_doc || return 1
  local i=0 out=""
  while [ "$i" -lt "${#S_IDS[@]}" ]; do
    out="${out}${S_IDS[$i]}=${S_STATES[$i]}
"
    i=$((i + 1))
  done
  [ -n "$out" ] || return 1
  printf '%s' "$out"
}

# _json_field LINE KEY — extract a string field from a JSON line. Returns ""
# when the key is not on that line. Values never contain a raw quote (the
# writer escapes them), so cutting at the next quote is exact.
_json_field() {
  case "$1" in
    *"\"$2\""*) ;;
    *) return 0 ;;
  esac
  # Whitespace is allowed on BOTH sides of the colon: `"id":"x"`, `"id": "x"`
  # and `"id" : "x"` are all legal JSON, and the two emitters are free to drift.
  printf '%s' "$1" |
    sed -e "s|.*\"$2\"[[:space:]]*:[[:space:]]*\"||" -e 's|".*||'
}

_status_word() {
  local w=""
  if [ -f "$STATUS_TXT" ]; then
    w="$(head -1 "$STATUS_TXT" 2>/dev/null)"
  fi
  if [ -z "$w" ] && [ -n "$STATUS_BIN" ]; then
    w="$(_status --quiet 2>/dev/null)"
  fi
  printf '%s' "$w"
}

# ---------------------------------------------------------------------------
# manual-action catalogue
# ---------------------------------------------------------------------------

_remediation_for() { # $1 = check id
  case "$1" in
    clt)
      printf '    run: xcode-select --install   (then re-run install.sh)\n'
      ;;
    xcode)
      printf "    install Xcode from the Mac App Store, or via 'xcodes' /\n"
      printf '    https://developer.apple.com/download/applications/\n'
      ;;
    xcode_license)
      printf '    run: sudo xcodebuild -license accept\n'
      printf '    then: sudo xcodebuild -runFirstLaunch\n'
      printf '    and:  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer\n'
      ;;
    homebrew)
      local brew_cmd="/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      printf '    re-run install.sh (it installs Homebrew), or run the Homebrew installer:\n'
      printf '    %s\n' "$brew_cmd"
      ;;
    chezmoi)
      printf '    re-run install.sh — it installs chezmoi into ~/.local/bin\n'
      ;;
    onepassword_app)
      printf '    install the 1Password 8 desktop app from https://1password.com/downloads\n'
      ;;
    onepassword_cli)
      printf '    1Password -> Settings -> Developer -> enable "Integrate with 1Password CLI"\n'
      ;;
    onepassword_vault)
      printf '    unlock 1Password; if the vault name is wrong, fix it with: install.sh --reprompt\n'
      ;;
    ssh_signing_key | github_ssh)
      printf '    1Password -> Settings -> Developer -> enable the SSH agent, and add the\n'
      printf '    SSH key item (then approve the agent prompt when it appears)\n'
      ;;
    brewfile)
      printf '    re-run install.sh, or run: brew bundle --global\n'
      ;;
    mise)
      printf '    run: mise install\n'
      ;;
    secrets)
      printf '    unlock 1Password, then re-run install.sh so ~/.config/sh/secrets.env is\n'
      printf '    rewritten (mode 0600)\n'
      ;;
    git_remote_ssh)
      printf '    re-run install.sh — the switch-to-ssh hook flips origin to git@github.com\n'
      printf '    once GitHub SSH authentication works\n'
      ;;
    *)
      printf '    re-run install.sh\n'
      ;;
  esac
}

_state_of() { # $1 = check id -> prints its state, or "" when unknown
  local id="$1"
  local i=0
  local n=${#S_IDS[@]}
  while [ "$i" -lt "$n" ]; do
    if [ "${S_IDS[$i]}" = "$id" ]; then
      printf '%s' "${S_STATES[$i]}"
      return 0
    fi
    i=$((i + 1))
  done
  return 0
}

# ---------------------------------------------------------------------------
# Stage 0 — preflight (read-only, never exits)
# ---------------------------------------------------------------------------

stage0_preflight() {
  _banner "STAGE 0/5 — PREFLIGHT (read-only)"

  local osver="" arch="" net="" disk="" sudo_state="" sock="" dfline=""

  arch="$(_os_name)/$(uname -m 2>/dev/null)"
  if _is_darwin && _have sw_vers; then
    osver="macOS $(sw_vers -productVersion 2>/dev/null) (build $(sw_vers -buildVersion 2>/dev/null))"
  else
    osver="$(_os_name)"
  fi
  _row "OS" "$osver"
  _row "Arch" "$arch"

  if _have curl; then
    if [ "$DRY_RUN" -eq 1 ]; then
      net="not probed (--dry-run)"
    elif curl -fsS --max-time 8 -o /dev/null https://github.com 2>/dev/null; then
      net="github.com reachable"
    else
      net="UNREACHABLE (offline or proxied) — downloads will be deferred"
    fi
  elif _have wget; then
    net="curl absent, wget present"
  else
    net="no curl and no wget — cannot download anything"
  fi
  _row "Network" "$net"

  dfline="$(df -h "$HOME" 2>/dev/null | tail -1 | tr -s ' ')"
  disk="$(printf '%s' "$dfline" | cut -d' ' -f4)"
  _row "Free disk" "${disk:-unknown} free on ${HOME}"

  if [ "$DRY_RUN" -eq 1 ]; then
    sudo_state="not probed (--dry-run)"
  elif sudo -n true >/dev/null 2>&1; then
    sudo_state="cached (no password needed right now)"
  else
    sudo_state="not cached (a password prompt will appear if sudo is needed)"
  fi
  _row "Sudo" "$sudo_state"

  sock="$(_op_agent_sock)"
  if [ -S "$sock" ]; then
    _row "1Password agent" "socket present"
  else
    _row "1Password agent" "socket absent"
  fi

  printf '\n'
  if [ "$DRY_RUN" -eq 0 ] && [ -n "$STATUS_BIN" ]; then
    _log_info "full check table from ${STATUS_BIN}:"
    printf '\n'
    _status || _log_warn "bootstrap-status did not run; continuing"
  else
    if [ "$DRY_RUN" -eq 1 ]; then
      _log_info "dry run — inline read-only probes only (bootstrap-status, brew and chezmoi are not invoked):"
    else
      _log_info "bootstrap-status is not available yet (fresh machine) — minimal inline probe:"
    fi
    _row "Command Line Tools" "$(_preflight_clt)"
    _row "Xcode" "$([ -d /Applications/Xcode.app ] && echo present || echo absent)"
    _row "Xcode license" "$(_preflight_license)"
    _row "Homebrew" "$(_preflight_brew)"
    _row "chezmoi" "$(_preflight_chezmoi)"
    _row "1Password.app" "$(_preflight_op_app)"
    _row "op CLI" "$(_have op && echo present || echo absent)"
    _row "GitHub SSH" "not probed (bootstrap-status not invoked)"
  fi

  printf '\n'
  _log_ok "stage 0 summary: preflight complete, nothing was changed"
}

_preflight_clt() {
  if ! _is_darwin; then
    printf 'n/a (not macOS)'
    return 0
  fi
  if _clt_ready; then
    printf 'installed'
  elif _have pkgutil && pkgutil --pkg-info=com.apple.pkg.CLTools_Executables >/dev/null 2>&1; then
    printf 'package present but xcrun/xcode-select broken'
  else
    printf 'ABSENT'
  fi
}

_preflight_license() {
  if [ ! -d /Applications/Xcode.app ]; then
    printf 'n/a (Xcode not installed)'
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'not probed (--dry-run)'
    return 0
  fi
  if _xcode_license_ok; then
    printf 'accepted'
  else
    printf 'NOT accepted / first-launch incomplete'
  fi
}

_preflight_op_app() {
  if [ -d /Applications/1Password.app ] || [ -d "${HOME}/Applications/1Password.app" ]; then
    printf 'present'
  else
    printf 'absent'
  fi
}

_preflight_brew() {
  local p=""
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$p" ]; then
      printf '%s' "$p"
      return 0
    fi
  done
  if _have brew; then
    command -v brew
    return 0
  fi
  printf 'ABSENT'
}

_preflight_chezmoi() {
  if _have chezmoi; then
    command -v chezmoi
  elif [ -x "${HOME}/.local/bin/chezmoi" ]; then
    printf '%s' "${HOME}/.local/bin/chezmoi"
  else
    printf 'ABSENT'
  fi
}

# ---------------------------------------------------------------------------
# Stage 1 — Command Line Tools gate (looping, skippable, never fatal)
# ---------------------------------------------------------------------------

stage1_clt() {
  _banner "STAGE 1/5 — COMMAND LINE TOOLS GATE"

  if ! _is_darwin; then
    _log_ok "stage 1 summary: not macOS — no Command Line Tools gate"
    return 0
  fi

  if [ "$SKIP_CLT" -eq 1 ]; then
    DEFER_CLT=1
    _defer "Command Line Tools — skipped via --skip-clt; the installer will continue and configure this on a later pass"
    _log_warn "stage 1 summary: CLT gate skipped; chezmoi will use its builtin git"
    return 0
  fi

  if _clt_ready; then
    _log_ok "Command Line Tools are present and xcrun resolves the macOS SDK"
    _log_ok "stage 1 summary: nothing to do"
    return 0
  fi

  _log_warn "Command Line Tools are missing. They matter because:"
  _log_warn "  /usr/bin/git and /usr/bin/python3 are CLT shims — without CLT they fail"
  _log_warn "  clang, make and the Homebrew installer all require them too"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] would run: xcode-select --install\n'
    printf '  [dry-run] would then poll every %ss for up to %ss, offering s=skip / r=re-raise\n' "$CLT_INTERVAL" "$CLT_TIMEOUT"
    DEFER_CLT=1
    _defer "Command Line Tools — not verified because of --dry-run"
    _log_warn "stage 1 summary: dry run, CLT treated as deferred"
    return 0
  fi

  _log_info "Raising the Command Line Tools install dialog..."
  xcode-select --install >/dev/null 2>&1 ||
    _log_warn "xcode-select --install returned non-zero (it may already be running)"

  local elapsed=0
  local key=""
  local rc=0

  while [ "$elapsed" -lt "$CLT_TIMEOUT" ]; do
    if _clt_ready; then
      printf '\n'
      _log_ok "Command Line Tools installed after ${elapsed}s"
      _log_ok "stage 1 summary: CLT present, chezmoi may use the system git"
      return 0
    fi

    if _is_tty; then
      # One updating line, not a wall of text.
      printf '\r\033[K  waiting for Command Line Tools... %ss/%ss  [s=skip, r=re-raise dialog]   ' "$elapsed" "$CLT_TIMEOUT"
      key=""
      rc=0
      IFS= read -r -t "$CLT_INTERVAL" -n 1 key || rc=$?
      if [ "$rc" -eq 0 ] && [ -n "$key" ]; then
        case "$key" in
          s | S)
            printf '\n'
            DEFER_CLT=1
            _defer "Command Line Tools — skipped at the gate; the installer will continue and configure this on a later pass"
            _log_warn "stage 1 summary: CLT deferred by user; chezmoi will use its builtin git"
            return 0
            ;;
          r | R)
            printf '\n'
            _log_info "Re-raising the Command Line Tools install dialog..."
            xcode-select --install >/dev/null 2>&1 ||
              _log_warn "xcode-select --install returned non-zero"
            ;;
        esac
      fi
    else
      sleep "$CLT_INTERVAL"
      if [ $((elapsed % 60)) -eq 0 ]; then
        _log_info "waiting for Command Line Tools... ${elapsed}s/${CLT_TIMEOUT}s (no TTY, cannot skip interactively)"
      fi
    fi

    elapsed=$((elapsed + CLT_INTERVAL))
  done

  printf '\n'
  DEFER_CLT=1
  _defer "Command Line Tools — the installer will continue and configure this on a later pass"
  _log_warn "stage 1 summary: CLT gate timed out after ${CLT_TIMEOUT}s; chezmoi will use its builtin git"
  return 0
}

# ---------------------------------------------------------------------------
# Stage 2 — Xcode + license (optional, looping, never fatal)
# ---------------------------------------------------------------------------

stage2_xcode() {
  _banner "STAGE 2/5 — XCODE + LICENSE (OPTIONAL)"

  if ! _is_darwin; then
    _log_ok "stage 2 summary: not macOS — no Xcode gate"
    return 0
  fi

  if [ "$SKIP_XCODE" -eq 1 ]; then
    DEFER_XCODE=1
    _defer "Xcode — skipped via --skip-xcode"
    _log_ok "stage 2 summary: Xcode gate skipped"
    return 0
  fi

  if [ ! -d /Applications/Xcode.app ]; then
    if _ask "Install full Xcode? (Command Line Tools are sufficient for this repo)" n; then
      _log_info "Full Xcode is not installed. Two ways to get it:"
      _log_info "  1. Mac App Store -> search \"Xcode\" -> Install"
      _log_info "  2. \`brew install xcodesorg/made/xcodes\` then \`xcodes install --latest\`,"
      _log_info "     or download from https://developer.apple.com/download/applications/"
      DEFER_XCODE=1
      _defer "Xcode — wanted but not installed; install it and re-run install.sh"
      _log_warn "stage 2 summary: Xcode wanted but absent — deferred, continuing"
    else
      DEFER_XCODE=1
      _log_ok "Full Xcode not wanted — Command Line Tools are sufficient for this repo"
      _log_ok "stage 2 summary: Xcode intentionally skipped"
    fi
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] Xcode.app present; would check the license up to 3 times and offer:\n'
    printf '  [dry-run]   sudo xcodebuild -license accept\n'
    printf '  [dry-run]   sudo xcodebuild -runFirstLaunch\n'
    printf '  [dry-run]   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer\n'
    DEFER_XCODE=1
    _defer "Xcode license — not verified because of --dry-run"
    _log_warn "stage 2 summary: dry run, Xcode license not probed"
    return 0
  fi

  local attempt=1
  local reply=""
  local interactive=0
  if _is_tty && [ "$ASSUME_YES" -eq 0 ]; then
    interactive=1
  fi
  while [ "$attempt" -le 3 ]; do
    if _xcode_license_ok; then
      _log_ok "Xcode license accepted and first-launch components installed"
      _log_ok "stage 2 summary: Xcode ready"
      return 0
    fi

    _log_warn "Xcode is installed but its license / first-launch is not complete (attempt ${attempt}/3)."
    _log_warn "The exact fix is:  sudo xcodebuild -license accept"

    if _ask "Run 'sudo xcodebuild -license accept' now?" n; then
      if ! sudo -n true >/dev/null 2>&1; then
        _log_info "sudo is not cached, so a password prompt will appear."
      fi
      _run sudo xcodebuild -license accept ||
        _log_warn "sudo xcodebuild -license accept failed"
      _run sudo xcodebuild -runFirstLaunch ||
        _log_warn "sudo xcodebuild -runFirstLaunch failed"
      _run sudo xcode-select -s /Applications/Xcode.app/Contents/Developer ||
        _log_warn "sudo xcode-select -s failed"
    else
      _log_info "You can accept it in another terminal window:"
      _log_info "  sudo xcodebuild -license accept && sudo xcodebuild -runFirstLaunch"
      if [ "$interactive" -eq 0 ]; then
        # --yes or no TTY: there is nobody to go and accept the license, so
        # looping three times would only repeat the same message. Defer at once.
        _log_info "non-interactive or --yes — deferring instead of re-checking"
        break
      fi
      printf 'Press Enter to re-check, or type q to defer and continue: '
      reply=""
      IFS= read -r reply || reply=""
      if [ "$reply" = "q" ] || [ "$reply" = "Q" ]; then
        break
      fi
    fi
    attempt=$((attempt + 1))
  done

  DEFER_XCODE=1
  _defer "Xcode license — still not accepted; run: sudo xcodebuild -license accept"
  _log_warn "stage 2 summary: Xcode license deferred, continuing"
  return 0
}

# ---------------------------------------------------------------------------
# Stage 3 — chezmoi bootstrap
# ---------------------------------------------------------------------------

_install_chezmoi_via_installer() { # $1 = bin dir
  local bin_dir="$1"
  # The `$(...)` below must reach the user's shell literally in dry-run output,
  # so it is held in a variable rather than inside a printf format string.
  local curl_cmd="sh -c \"\$(curl -fsSL https://git.io/chezmoi)\" -- -b ${bin_dir}"
  local wget_cmd="sh -c \"\$(wget -qO- https://git.io/chezmoi)\" -- -b ${bin_dir}"
  if _have curl; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '  [dry-run] would run: %s\n' "$curl_cmd"
      return 0
    fi
    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$bin_dir"
  elif _have wget; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '  [dry-run] would run: %s\n' "$wget_cmd"
      return 0
    fi
    sh -c "$(wget -qO- https://git.io/chezmoi)" -- -b "$bin_dir"
  else
    _log_err "To install chezmoi, you must have curl or wget installed."
    return 1
  fi
}

stage3_bootstrap() {
  _banner "STAGE 3/5 — CHEZMOI BOOTSTRAP"

  _run create_required_dirs

  local bin_dir="${HOME}/.local/bin"
  local existing=""
  local brew_bin=""
  existing="$(_preflight_chezmoi)"

  if [ "$existing" != "ABSENT" ]; then
    CHEZMOI="$existing"
    _log_ok "chezmoi already installed at ${CHEZMOI}"
  else
    _log_info "chezmoi not found — installing it"
    brew_bin="$(_preflight_brew)"
    if [ "$brew_bin" != "ABSENT" ]; then
      _log_info "Homebrew is available, preferring: ${brew_bin} install chezmoi"
      if _run "$brew_bin" install chezmoi; then
        _log_ok "brew install chezmoi succeeded"
      else
        _log_warn "brew install chezmoi failed — falling back to the curl installer"
      fi
    fi
    existing="$(_preflight_chezmoi)"
    if [ "$existing" = "ABSENT" ]; then
      if ! _install_chezmoi_via_installer "$bin_dir"; then
        # This is one of the three permitted hard exits: no curl, no wget and no
        # brew means nothing can ever be downloaded.
        _log_err "Cannot continue without chezmoi and without curl/wget/brew."
        exit 1
      fi
    fi
    existing="$(_preflight_chezmoi)"
    if [ "$existing" = "ABSENT" ]; then
      _log_err "chezmoi is still not on PATH after installing into ${bin_dir}."
      _log_warn "Add ${bin_dir} to PATH and re-run install.sh to resume."
      _defer "chezmoi bootstrap — the binary could not be located after install"
      _log_err "stage 3 summary: chezmoi unavailable, skipping init/apply"
      return 0
    fi
    CHEZMOI="$existing"
    _log_ok "chezmoi installed at ${CHEZMOI}"
  fi

  # Git strategy. If CLT is deferred, /usr/bin/git is a shim that pops a GUI
  # dialog and fails, which would break the clone itself (chezmoi's
  # useBuiltinGitAutoFunc picks system git whenever git is on PATH). Force the
  # builtin git in that case.
  if [ "$DEFER_CLT" -eq 1 ]; then
    BUILTIN_GIT_FLAG="--use-builtin-git=true"
    _log_warn "Command Line Tools deferred — using ${BUILTIN_GIT_FLAG} so the /usr/bin/git shim cannot break the clone"
  else
    BUILTIN_GIT_FLAG="--use-builtin-git=auto"
    _log_info "Command Line Tools present — using ${BUILTIN_GIT_FLAG}"
  fi

  local cfg="${XDG_CONFIG_HOME:-${HOME}/.config}/chezmoi/chezmoi.yaml"
  local -a init_args
  init_args=(init --apply "$BUILTIN_GIT_FLAG")
  if [ "$VERBOSE" -eq 1 ]; then
    init_args+=(-v)
  fi
  if [ "$REPROMPT" -eq 1 ]; then
    init_args+=(--prompt)
    _log_info "--reprompt: every prompt*Once value will be re-asked"
  elif [ -f "$cfg" ]; then
    # chezmoi init defaults to --data=true in v2.72.2, so existing answers in
    # the rendered config are preserved on a re-run.
    _log_info "existing config ${cfg} found — preserving current answers (use --reprompt to re-ask)"
  fi

  if [ -f "${SCRIPT_DIR}/.chezmoi.yaml.tmpl" ] || [ -f "${SCRIPT_DIR}/.chezmoiroot" ]; then
    _log_info "Running from an existing clone at ${SCRIPT_DIR} — using it as the chezmoi source"
    init_args+=("--source=${SCRIPT_DIR}")
  else
    _log_info "Cloning dotfiles via HTTPS (no SSH key required)..."
    init_args+=("$REPO")
  fi

  # Deliberately NOT exec'd: the exit status is captured so stages 4 and 5 still
  # run and the user always gets a report.
  local rc=0
  _run "$CHEZMOI" "${init_args[@]}" || rc=$?
  STAGE3_RC=$rc

  if [ "$rc" -ne 0 ]; then
    _log_err "chezmoi init --apply exited ${rc}"
    _defer "chezmoi init/apply — exited ${rc}; the converge loop and report will still run"
    _log_err "stage 3 summary: init failed, continuing to the converge loop"
  else
    _log_ok "stage 3 summary: chezmoi init --apply completed"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Stage 4 — converge loop
# ---------------------------------------------------------------------------

_print_outstanding() {
  local i=0
  local n=${#S_IDS[@]}
  local found=0
  if [ "$n" -eq 0 ]; then
    _log_warn "no bootstrap-status document available — cannot list outstanding checks"
    return 0
  fi
  printf '\n'
  _log_info "outstanding checks:"
  while [ "$i" -lt "$n" ]; do
    case "${S_STATES[$i]}" in
      green) ;;
      *)
        found=1
        printf '  [%s] %s\n' "${S_STATES[$i]}" "${S_IDS[$i]}"
        printf '    %s\n' "${S_MSGS[$i]}"
        # _remediation_for already indents by 4; add 2 so the fix sits one level
        # deeper than the message it belongs to.
        _remediation_for "${S_IDS[$i]}" | sed 's/^/  /'
        ;;
    esac
    i=$((i + 1))
  done
  if [ "$found" -eq 0 ]; then
    _log_ok "nothing outstanding"
  fi
  return 0
}

stage4_converge() {
  _banner "STAGE 4/5 — CONVERGE LOOP"

  if [ "$MAX_PASSES" -le 0 ]; then
    _log_info "max-passes=${MAX_PASSES} — skipping the converge loop entirely"
    _log_ok "stage 4 summary: skipped by request"
    return 0
  fi

  if [ -z "$CHEZMOI" ]; then
    _log_warn "chezmoi is unavailable — cannot converge"
    _defer "converge loop — chezmoi binary not located"
    _log_warn "stage 4 summary: skipped, chezmoi unavailable"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    local p=1
    while [ "$p" -le "$MAX_PASSES" ]; do
      printf '  [dry-run] pass %s/%s would run: %s apply --keep-going %s%s\n' \
        "$p" "$MAX_PASSES" "$CHEZMOI" "$BUILTIN_GIT_FLAG" \
        "$([ "$VERBOSE" -eq 1 ] && printf ' -v')"
      p=$((p + 1))
    done
    printf '  [dry-run] would stop on: green, or two identical id=state snapshots, or %s passes\n' "$MAX_PASSES"
    _log_ok "stage 4 summary: dry run, nothing applied"
    return 0
  fi

  local -a apply_args
  apply_args=(apply --keep-going "$BUILTIN_GIT_FLAG")
  if [ "$VERBOSE" -eq 1 ]; then
    apply_args+=(-v)
  fi

  local pass=1
  local rc=0
  local word=""
  local doc=""
  local prev_doc=""
  local reply=""

  while [ "$pass" -le "$MAX_PASSES" ]; do
    _log_info "converge pass ${pass}/${MAX_PASSES}: chezmoi apply --keep-going"
    rc=0
    _run "$CHEZMOI" "${apply_args[@]}" || rc=$?
    if [ "$rc" -ne 0 ]; then
      # A non-zero apply must never terminate the installer: run_* scripts can
      # fail for reasons that a later pass (or a human) resolves.
      _log_warn "chezmoi apply exited ${rc} — continuing; a later pass may still converge"
    fi

    word="$(_status_word)"
    _log_info "bootstrap-status after pass ${pass}: ${word:-unknown}"

    if [ "$word" = "green" ]; then
      CONVERGED="yes"
      _log_ok "converged: bootstrap-status is green after ${pass} pass(es)"
      _log_ok "stage 4 summary: converged in ${pass} pass(es)"
      return 0
    fi

    # D7: snapshot a SEMANTIC key — "id=state" per check in document order —
    # rather than the document text. Two identical keys mean no further progress
    # is possible without human action. An empty key means no document could be
    # read, which is treated as "no comparison possible", never as progress.
    doc=""
    doc="$(_status_key)" || doc=""
    if [ -n "$prev_doc" ] && [ -n "$doc" ] && [ "$prev_doc" = "$doc" ]; then
      _log_warn "no further progress: two consecutive passes produced an identical id=state snapshot"
      _log_warn "the remaining checks need human action — see the manual-actions list below"
      CONVERGED="stalled"
      break
    fi
    prev_doc="$doc"

    _load_status_doc
    _print_outstanding

    if [ "$pass" -lt "$MAX_PASSES" ]; then
      if _is_tty && [ "$ASSUME_YES" -eq 0 ]; then
        printf 'fix these now and press Enter to re-run, or type q to finish: '
        reply=""
        IFS= read -r reply || reply=""
        if [ "$reply" = "q" ] || [ "$reply" = "Q" ]; then
          _log_info "finishing at the user's request after ${pass} pass(es)"
          CONVERGED="user-stop"
          break
        fi
      else
        _log_info "non-interactive or --yes: continuing straight to the next pass"
      fi
    fi

    pass=$((pass + 1))
  done

  case "$CONVERGED" in
    stalled)
      _log_warn "stage 4 summary: stalled, human action required"
      ;;
    user-stop)
      _log_warn "stage 4 summary: stopped by the user before converging"
      ;;
    *)
      _log_warn "stage 4 summary: reached the pass limit (${MAX_PASSES}) without going green"
      ;;
  esac
  return 0
}

# ---------------------------------------------------------------------------
# Stage 5 — postflight report + manual actions
# ---------------------------------------------------------------------------

_print_manual_actions() {
  local i=0
  local n=${#S_IDS[@]}
  local printed=0
  local brew_state=""

  printf '\n'
  _log_info "MANUAL ACTIONS (only what is actually amber/red):"

  if [ "$n" -eq 0 ]; then
    printf '  (no bootstrap-status document available — run: bootstrap-status)\n'
    return 0
  fi

  while [ "$i" -lt "$n" ]; do
    case "${S_STATES[$i]}" in
      green) ;;
      *)
        printed=1
        printf '\n  %s [%s]\n' "${S_IDS[$i]}" "${S_STATES[$i]}"
        printf '    %s\n' "${S_MSGS[$i]}"
        _remediation_for "${S_IDS[$i]}" | sed 's/^/  /'
        ;;
    esac
    i=$((i + 1))
  done

  # GUI-only approvals. These have no probe, so they are gated on Homebrew
  # actually being installed: before that, none of these apps exist yet and
  # listing them would be noise.
  brew_state="$(_state_of homebrew)"
  if [ "$brew_state" = "green" ]; then
    printed=1
    printf '\n  GUI-only approvals (cannot be automated):\n'
    printf '    System Settings -> Privacy & Security -> approve the Karabiner-Elements\n'
    printf '      driver extension, then reboot if prompted\n'
    printf '    System Settings -> Privacy & Security -> allow the Little Snitch /\n'
    printf '      Micro Snitch system extension\n'
    printf '    OrbStack: approve the privileged helper on first launch\n'
    printf '    System Settings -> Privacy & Security -> Accessibility / Input Monitoring\n'
    printf '      for Hammerspoon, Alfred, AutoRaise, Homerow, Karabiner\n'
    printf '    run: mas signin   (the Brewfile installs mas; the repo currently has no\n'
    printf '      mas entries)\n'
    printf '    run: set-shell-zsh   (registers Homebrew zsh in /etc/shells; no chezmoi\n'
    printf '      hook does this)\n'
    printf '    run: exec zsh -l   (reload the shell)\n'
  fi

  if [ "$printed" -eq 0 ]; then
    printf '  none — every check is green\n'
  fi
  return 0
}

stage5_postflight() {
  _banner "STAGE 5/5 — POSTFLIGHT REPORT"

  if [ -n "$STATUS_BIN" ]; then
    _log_info "refreshing bootstrap-status..."
    printf '\n'
    _status || _log_warn "bootstrap-status did not run"
  elif [ -f "$STATUS_TXT" ]; then
    _log_warn "bootstrap-status is not installed; cached overall state: $(head -1 "$STATUS_TXT" 2>/dev/null)"
  else
    _log_warn "bootstrap-status is not installed and no cached status exists"
  fi

  _load_status_doc
  _print_manual_actions

  local i=0
  local n=${#DEFERRED[@]}
  if [ "$n" -gt 0 ]; then
    printf '\n'
    _log_warn "DEFERRED BY THIS RUN (${n}):"
    while [ "$i" -lt "$n" ]; do
      printf '  - %s\n' "${DEFERRED[$i]}"
      i=$((i + 1))
    done
  fi

  if [ "$STAGE3_RC" -ne 0 ]; then
    printf '\n'
    _log_warn "note: chezmoi init --apply exited ${STAGE3_RC} during this run"
  fi

  printf '\n'
  _log_info "gate outcomes: defer_clt=${DEFER_CLT} defer_xcode=${DEFER_XCODE} (builtin git: ${BUILTIN_GIT_FLAG})"
  printf '\n'
  _log_info "To resume:   sh install.sh        (or ./install.sh)"
  _log_info "To inspect:  bootstrap-status     (shows what is still outstanding)"
  _log_info "To re-answer every chezmoi prompt: sh install.sh --reprompt"
  printf '\n'
  _log_ok "stage 5 summary: report complete — exiting 0 even though items are deferred"
  return 0
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"

  if ! _is_darwin && ! _is_linux; then
    _log_err "Unsupported operating system: $(_os_name). This installer supports macOS and Linux only."
    exit 1
  fi

  # POSIX-safe script dir. `command -v -- "$0"` (the previous idiom) fails when
  # the script is invoked as a bare `sh install.sh` because there is no slash to
  # anchor the lookup, so anchor it explicitly.
  local src="$0"
  case "$src" in
    */*) ;;
    *) src="./$src" ;;
  esac
  SCRIPT_DIR="$(cd -P -- "$(dirname -- "$src")" && pwd -P)"

  _find_status_bin

  _banner "neumachen/dotfiles bootstrap"
  _log_info "script directory: ${SCRIPT_DIR}"
  if [ -n "$STATUS_BIN" ]; then
    _log_info "bootstrap-status:  ${STATUS_BIN}"
  else
    _log_info "bootstrap-status:  not available yet (fresh machine) — using inline probes"
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    _log_warn "DRY RUN — every stage is walked but nothing is executed"
  fi

  stage0_preflight
  stage1_clt
  stage2_xcode

  # Publish the gate outcomes so the chezmoi scripts started by stage 3/4 can
  # see them (they mirror the bootstrap.defer_clt / bootstrap.defer_xcode data
  # keys in .chezmoi.yaml.tmpl).
  export BOOTSTRAP_DEFER_CLT="$DEFER_CLT"
  export BOOTSTRAP_DEFER_XCODE="$DEFER_XCODE"

  stage3_bootstrap
  stage4_converge
  stage5_postflight

  exit 0
}

main "$@"
