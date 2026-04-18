#!/usr/bin/env bash
set -Eeuo pipefail

GLOBAL_DIR="${1:?usage: install-aiderdesk-extensions.sh <global-dir> <seed-dir> <default-csv> [append-csv] [override-csv]}"
SEED_DIR="${2:?usage: install-aiderdesk-extensions.sh <global-dir> <seed-dir> <default-csv> [append-csv] [override-csv]}"
DEFAULT_EXTENSIONS_CSV="${3:-}"
APPEND_EXTENSIONS_CSV="${4:-}"
OVERRIDE_EXTENSIONS_CSV="${5:-}"

trim() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$GLOBAL_DIR" "$SEED_DIR"
rm -rf "$GLOBAL_DIR"/* "$SEED_DIR"/*

final_extensions="$DEFAULT_EXTENSIONS_CSV"
if [ -n "$OVERRIDE_EXTENSIONS_CSV" ]; then
  final_extensions="$OVERRIDE_EXTENSIONS_CSV"
elif [ -n "$APPEND_EXTENSIONS_CSV" ]; then
  final_extensions="${DEFAULT_EXTENSIONS_CSV},${APPEND_EXTENSIONS_CSV}"
fi

declare -A seen=()
requested_count=0
IFS=',' read -ra exts <<< "$final_extensions"
for ext in "${exts[@]}"; do
  ext="$(trim "$ext")"
  [ -n "$ext" ] || continue
  if [ -n "${seen["$ext"]+x}" ]; then
    continue
  fi
  seen["$ext"]=1
  requested_count=$((requested_count + 1))
  echo "Installing AiderDesk extension: $ext"
  npx --yes @aiderdesk/extensions install "$ext" --directory "$TMP_DIR"
done

if [ "$requested_count" -gt 0 ] && ! find "$TMP_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  echo "FATAL: No extension files were installed into $TMP_DIR." >&2
  exit 1
fi

if find "$TMP_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  cp -a "$TMP_DIR"/. "$GLOBAL_DIR"/
  cp -a "$TMP_DIR"/. "$SEED_DIR"/
fi

echo "AiderDesk extensions prepared in:"
echo "  Global: $GLOBAL_DIR"
echo "  Seed:   $SEED_DIR"
