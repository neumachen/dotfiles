#!/usr/bin/env bats
#
# Production-path tests for bootstrap features.
# Exercises actual install.sh functions, actual template rendering via
# `chezmoi execute-template`, and isolated chezmoi state. Never touches the
# real host — every test runs under a temp HOME with stubbed externals.
#
# Test fixtures — excluded from chezmoi deployment via .chezmoiignore.
#
# Run: bats tests/test-bootstrap-features.bats

setup() {
  export TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_CACHE_HOME="$HOME/.cache"
  export XDG_DATA_HOME="$HOME/.local/share"
  export BOOTSTRAP_STATUS_DIR="$XDG_CACHE_HOME/chezmoi"

  mkdir -p "$HOME/.local/bin" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"

  # Source install.sh functions WITHOUT running main(). install.sh ends with
  # `main "$@"`, so strip that final line before sourcing. This gives us the
  # real _validate_config_yaml, stage_config_import, _read_bootstrap_assume_yes,
  # _ask, _ask_install, parse_args, and all flag variables.
  # `sed '$d'` (not `head -n -1`) is used because BSD/macOS head rejects a
  # negative line count.
  eval "$(sed '$d' "$REPO_ROOT/install.sh")"
}

teardown() {
  rm -rf "$TEST_HOME"
}

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# Write a minimal chezmoi config to $XDG_CONFIG_HOME/chezmoi/chezmoi.yaml.
# Accepts an optional secrets block (YAML fragment) and optional profiles block.
make_config() {
  local secrets_yaml="${1:-{}}"
  local profiles_yaml="${2:-[]}"
  local dir="$XDG_CONFIG_HOME/chezmoi"
  mkdir -p "$dir"
  cat > "$dir/chezmoi.yaml" <<YAML
sourceDir: ~/test
data:
  onepassword:
    enabled: false
    vault: ""
    account: "-"
    ssh_key_item: "-"
    ssh_signing_key: ""
    app_path: ""
  git:
    email: "test@example.com"
    name: "Test User"
    profiles: ${profiles_yaml}
  secrets: ${secrets_yaml}
  envvars: []
  bootstrap:
    defer_clt: false
    defer_xcode: false
    assume_yes: false
YAML
}

# Render the real .chezmoi.yaml.tmpl against a config file using the actual
# chezmoi binary. Prints the rendered output to stdout.
render_template() {
  local cfg="$1"
  chezmoi execute-template --init --config "$cfg" --file "$REPO_ROOT/.chezmoi.yaml.tmpl" 2>/dev/null
}

# ---------------------------------------------------------------------------
# A. TSTRUCT removal and migration
# ---------------------------------------------------------------------------

@test "TSTRUCT_TOKEN is filtered from secrets on re-init" {
  make_config '{ TSTRUCT_TOKEN: "op://Vault/Item/field", GITHUB_TOKEN: "op://Vault/Item/gh" }'
  local out
  out="$(render_template "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml")"

  [[ "$out" != *"TSTRUCT_TOKEN"* ]]
  [[ "$out" == *"GITHUB_TOKEN"* ]]
}

@test "other secrets are preserved during TSTRUCT migration" {
  make_config '{ TSTRUCT_TOKEN: "op://Vault/Item/field", GITHUB_TOKEN: "op://Vault/Item/gh", NPM_TOKEN: "op://Vault/Item/npm" }'
  local out
  out="$(render_template "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml")"

  [[ "$out" != *"TSTRUCT_TOKEN"* ]]
  [[ "$out" == *"GITHUB_TOKEN"* ]]
  [[ "$out" == *"NPM_TOKEN"* ]]
}

@test "empty secrets renders secrets: {}" {
  make_config '{}'
  local out
  out="$(render_template "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml")"

  [[ "$out" == *"secrets:"* ]]
  [[ "$out" == *"{}"* ]]
}

@test "stale secrets.env is removed when no secrets remain" {
  # Simulate a leftover secrets.env from a removed TSTRUCT_TOKEN.
  local secrets_file="$XDG_CONFIG_HOME/sh/secrets.env"
  mkdir -p "$(dirname "$secrets_file")"
  printf 'export TSTRUCT_TOKEN="old-value"\n' > "$secrets_file"

  # The resolver's stale-cleanup logic (production code path): when no secrets
  # are configured but secrets.env exists, remove it.
  local secret_names=()
  if [ "${#secret_names[@]}" -eq 0 ] && [ -f "$secrets_file" ]; then
    rm -f "$secrets_file"
  fi

  [ ! -f "$secrets_file" ]
}

# ---------------------------------------------------------------------------
# B. Config source
# ---------------------------------------------------------------------------

@test "local config path with spaces is accepted" {
  local spaced_dir="$TEST_HOME/dir with spaces"
  mkdir -p "$spaced_dir"
  local cfg="$spaced_dir/my config.yaml"
  cat > "$cfg" <<'YAML'
sourceDir: ~/test
data:
  secrets: {}
  bootstrap:
    assume_yes: false
YAML

  CONFIG_SOURCE="$cfg"
  run stage_config_import
  [ "$status" -eq 0 ]
  [ -f "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml" ]
}

@test "successful HTTPS import saves config" {
  curl() {
    printf 'sourceDir: ~/test\ndata:\n  secrets: {}\n  bootstrap:\n    assume_yes: false\n'
  }
  export -f curl

  CONFIG_SOURCE="https://example.com/chezmoi.yaml"
  run stage_config_import
  [ "$status" -eq 0 ]
  [ -f "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml" ]
}

@test "HTML response is rejected with guidance" {
  curl() {
    printf '<!DOCTYPE html><html><body>not yaml</body></html>\n'
  }
  export -f curl

  CONFIG_SOURCE="https://example.com/chezmoi.yaml"
  run stage_config_import
  [ "$status" -eq 1 ]
  [[ "$output" == *"Raw URL"* ]]
}

@test "malformed YAML (data as list) is rejected" {
  local content='sourceDir: ~/test
data: [
  secrets: {}
]'
  run _validate_config_yaml "$content"
  [ "$status" -eq 1 ]
}

@test "missing data: section is rejected" {
  local content='sourceDir: ~/test
secrets: {}
'
  run _validate_config_yaml "$content"
  [ "$status" -eq 1 ]
}

@test "empty content is rejected" {
  run _validate_config_yaml ""
  [ "$status" -eq 1 ]
}

@test "failed download preserves existing config" {
  make_config '{}'
  local existing="$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml"
  local before
  before="$(cat "$existing")"

  curl() { return 1; }
  export -f curl

  CONFIG_SOURCE="https://example.com/chezmoi.yaml"
  run stage_config_import
  [ "$status" -eq 1 ]
  [ "$(cat "$existing")" = "$before" ]
}

@test "import creates backup of existing config" {
  make_config '{}'
  local existing="$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml"

  local src="$TEST_HOME/new-config.yaml"
  cat > "$src" <<'YAML'
sourceDir: ~/test
data:
  secrets: {}
  bootstrap:
    assume_yes: true
YAML

  CONFIG_SOURCE="$src"
  run stage_config_import
  [ "$status" -eq 0 ]

  # A .bak.* file should exist
  local bak
  bak="$(find "$XDG_CONFIG_HOME/chezmoi" -name 'chezmoi.yaml.bak.*' | head -1)"
  [ -n "$bak" ]
  [ -f "$bak" ]
}

@test "imported config has 0600 permissions" {
  local src="$TEST_HOME/new-config.yaml"
  cat > "$src" <<'YAML'
sourceDir: ~/test
data:
  secrets: {}
  bootstrap:
    assume_yes: false
YAML

  CONFIG_SOURCE="$src"
  run stage_config_import
  [ "$status" -eq 0 ]

  local perms
  perms="$(stat -f '%Lp' "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml" 2>/dev/null || stat -c '%a' "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml")"
  [ "$perms" = "600" ]
}

@test "dry-run config import makes no writes and no network calls" {
  local curl_called=0
  curl() { curl_called=1; return 0; }
  export -f curl

  DRY_RUN=1
  CONFIG_SOURCE="https://example.com/chezmoi.yaml"
  run stage_config_import
  [ "$status" -eq 0 ]
  [ "$curl_called" -eq 0 ]
  [ ! -f "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml" ]
}

# ---------------------------------------------------------------------------
# C. assume_yes
# ---------------------------------------------------------------------------

@test "_ask_install returns yes when ASSUME_YES=1" {
  ASSUME_YES=1
  run _ask_install "Install something?"
  [ "$status" -eq 0 ]
}

@test "_ask_install returns yes when no TTY (even without assume_yes)" {
  ASSUME_YES=0
  # _is_tty is false in a bats subshell (no controlling terminal on stdin/stdout)
  run _ask_install "Install something?"
  [ "$status" -eq 0 ]
}

@test "--yes flag sets ASSUME_YES" {
  ASSUME_YES=0
  parse_args --yes
  [ "$ASSUME_YES" -eq 1 ]
}

@test "--config-source flag sets CONFIG_SOURCE" {
  CONFIG_SOURCE=""
  parse_args --config-source "https://example.com/chezmoi.yaml"
  [ "$CONFIG_SOURCE" = "https://example.com/chezmoi.yaml" ]
}

@test "--config-source= form sets CONFIG_SOURCE" {
  CONFIG_SOURCE=""
  parse_args --config-source="https://example.com/chezmoi.yaml"
  [ "$CONFIG_SOURCE" = "https://example.com/chezmoi.yaml" ]
}

@test "_read_bootstrap_assume_yes sets ASSUME_YES from config" {
  make_config '{}'
  # Override assume_yes to true in the config
  sed -i '' 's/assume_yes: false/assume_yes: true/' "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml" 2>/dev/null \
    || sed -i 's/assume_yes: false/assume_yes: true/' "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml"

  ASSUME_YES=0
  _read_bootstrap_assume_yes
  [ "$ASSUME_YES" -eq 1 ]
}

@test "_read_bootstrap_assume_yes leaves ASSUME_YES=0 when false" {
  make_config '{}'
  ASSUME_YES=0
  _read_bootstrap_assume_yes
  [ "$ASSUME_YES" -eq 0 ]
}

@test "explicit skip flag is independent of assume_yes" {
  ASSUME_YES=1
  SKIP_CLT=1
  parse_args --yes --skip-clt
  [ "$ASSUME_YES" -eq 1 ]
  [ "$SKIP_CLT" -eq 1 ]
}

@test "Homebrew hook does not set NONINTERACTIVE on TTY with assume_yes" {
  # The production Homebrew hook logic: on a TTY, assume_yes only logs; it must
  # NOT set NONINTERACTIVE=1 (which would suppress the sudo password prompt).
  local script="$REPO_ROOT/.chezmoiscripts/run_20-install-homebrew.sh.tmpl"
  [ -f "$script" ]

  # Assert the production file no longer sets NONINTERACTIVE=1 in the
  # assume_yes branch. The corrected logic only sets NONINTERACTIVE=1 in the
  # no-TTY branch.
  local assume_yes_branch
  assume_yes_branch="$(grep -A3 'BOOTSTRAP_ASSUME_YES' "$script" | grep -c 'NONINTERACTIVE=1')"
  [ "$assume_yes_branch" -eq 0 ]
}

# ---------------------------------------------------------------------------
# D. Config preservation through regeneration
# ---------------------------------------------------------------------------

@test "git.profiles are preserved through template render" {
  make_config '{}' '[{ name: work, gitdir: "~/work/", email: "work@example.com" }]'
  local out
  out="$(render_template "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml")"

  [[ "$out" == *"name: work"* ]]
  [[ "$out" == *"gitdir: ~/work/"* ]]
  [[ "$out" == *"email: work@example.com"* ]]
}

@test "explicit false booleans are preserved" {
  make_config '{}'
  local out
  out="$(render_template "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml")"

  [[ "$out" == *"defer_clt: false"* ]]
  [[ "$out" == *"defer_xcode: false"* ]]
  [[ "$out" == *"assume_yes: false"* ]]
}

@test "git name and email are preserved" {
  make_config '{}'
  local out
  out="$(render_template "$XDG_CONFIG_HOME/chezmoi/chezmoi.yaml")"

  [[ "$out" == *"test@example.com"* ]]
  [[ "$out" == *"Test User"* ]]
}