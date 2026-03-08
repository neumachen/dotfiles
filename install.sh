#!/bin/sh

# https://github.com/chezmoi/dotfiles/blob/master/install.sh

set -e # -e: exit on error

HELFERLEIN_DIR="${HOME}/.local/share/meine-helferlein"
if [ -d "${HELFERLEIN_DIR}" ]; then
  export PATH="${HELFERLEIN_DIR}:${PATH}"
fi

_log_info()  { if command -v echo-info  >/dev/null 2>&1; then echo-info  "$@"; else echo "[INFO] --- $*"; fi; }
_log_ok()    { if command -v echo-ok    >/dev/null 2>&1; then echo-ok    "$@"; else echo "[SUCCESS] --- $*"; fi; }
_log_warn()  { if command -v echo-warn  >/dev/null 2>&1; then echo-warn  "$@"; else echo "[WARN] --- $*" >&2; fi; }
_log_err()   { if command -v echo-err   >/dev/null 2>&1; then echo-err   "$@"; else echo "[ERROR] --- $*" >&2; fi; }

# Create required directories before chezmoi runs
# These are needed by various dotfiles and chezmoi itself
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

create_required_dirs

if [ ! "$(command -v chezmoi)" ]; then
  bin_dir="${HOME}/.local/bin"
  chezmoi="${bin_dir}/chezmoi"
  if command -v curl >/dev/null 2>&1; then
    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$bin_dir"
  elif command -v wget >/dev/null 2>&1; then
    sh -c "$(wget -qO- https://git.io/chezmoi)" -- -b "$bin_dir"
  else
    _log_err "To install chezmoi, you must have curl or wget installed."
    exit 1
  fi
else
  chezmoi=chezmoi
fi

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

# Check if we're running from an existing source directory
if [ -f "${script_dir}/.chezmoi.yaml.tmpl" ] || [ -f "${script_dir}/.chezmoiroot" ]; then
  # Running from existing clone - use local source, skip git operations initially
  exec "$chezmoi" init --apply "--source=${script_dir}"
else
  # Fresh install - clone via HTTPS (no SSH key required)
  repo="https://github.com/neumachen/dotfiles.git"
  
  _log_info "Cloning dotfiles via HTTPS (no SSH key required)..."
  exec "$chezmoi" init --apply "$repo"
fi
