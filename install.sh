#!/bin/sh

# https://github.com/chezmoi/dotfiles/blob/master/install.sh

set -e # -e: exit on error

# Create required directories before chezmoi runs
# These are needed by various dotfiles and chezmoi itself
create_required_dirs() {
  echo "Creating required directories..."
  
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
    echo "To install chezmoi, you must have curl or wget installed." >&2
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
  
  echo "Cloning dotfiles via HTTPS (no SSH key required)..."
  exec "$chezmoi" init --apply "$repo"
fi
