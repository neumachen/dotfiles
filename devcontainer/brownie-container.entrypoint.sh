#!/usr/bin/env bash
set -euo pipefail

umask 077

mkdir -p /workspace /data

# Create tool-specific subdir if the image sets TOOL_DATA_SUBDIR
if [[ -n "${TOOL_DATA_SUBDIR:-}" ]]; then
  mkdir -p "/data/${TOOL_DATA_SUBDIR}"
fi

export GIT_CONFIG_GLOBAL="${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}"

exec "$@"
