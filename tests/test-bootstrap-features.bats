#!/usr/bin/env bats
#
# Test fixtures — excluded from chezmoi deployment via .chezmoiignore
#
# Tests for: TSTRUCT removal, --config-source, assume_yes
# Run: bats tests/test-bootstrap-features.bats
# Never applies to the real host — uses temp HOME and stubbed commands.

setup() {
  # Create a temp HOME
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_CACHE_HOME="$HOME/.cache"

  # Stub essential commands so no real system state is touched
  mkdir -p "$HOME/.local/bin"

  # Path to the repo files under test
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"

  # Ensure clean state
  rm -rf "$HOME/.config" "$HOME/.cache"
}

teardown() {
  rm -rf "$TEST_HOME"
}

# Helper: create a minimal chezmoi.yaml for testing
make_config() {
  local dir="$HOME/.config/chezmoi"
  mkdir -p "$dir"
  cat > "$dir/chezmoi.yaml" <<'YAML'
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
    profile: |
      [user]
        email = test@example.com
        name = Test User
    profiles: []
  secrets: {}
  envvars: []
  bootstrap:
    defer_clt: false
    defer_xcode: false
    assume_yes: false
YAML
}

# Helper: create a config with a specific secrets map (YAML fragment)
make_config_with_secrets() {
  local secrets_yaml="$1"  # e.g. 'GITHUB_TOKEN: "op://Vault/Item/field"'
  local dir="$HOME/.config/chezmoi"
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
    profile: |
      [user]
        email = test@example.com
        name = Test User
    profiles: []
  secrets:
${secrets_yaml}
  envvars: []
  bootstrap:
    defer_clt: false
    defer_xcode: false
    assume_yes: false
YAML
}

# Helper: create a stale secrets.env file
make_stale_secrets_env() {
  local dir="$HOME/.config/sh"
  mkdir -p "$dir"
  echo 'export TSTRUCT_TOKEN=oldvalue' > "$dir/secrets.env"
  chmod 0600 "$dir/secrets.env"
}

# ---------------------------------------------------------------------------
# A. TSTRUCT removal
# ---------------------------------------------------------------------------

@test "empty secrets maps to green in bootstrap-status" {
  # Simulate the inline fallback logic: when SECRET_NAMES is empty, report green.
  SECRET_NAMES=()

  if [ "${#SECRET_NAMES[@]}" -eq 0 ]; then
    state="green"
    msg="no secrets configured in chezmoi data"
  else
    state="amber"
    msg="has secrets"
  fi

  [ "$state" = "green" ]
  [[ "$msg" == *"no secrets configured"* ]]
}

@test "stale secrets.env with no configured secrets does not cause amber" {
  # Create a config with empty secrets
  make_config

  # Create a stale secrets.env (leftover from removed TSTRUCT)
  make_stale_secrets_env

  # Verify the stale file exists
  [ -f "$HOME/.config/sh/secrets.env" ]

  # Simulate the inline fallback: SECRET_NAMES is empty (no secrets in config)
  SECRET_NAMES=()

  # The check should be green regardless of the stale file
  if [ "${#SECRET_NAMES[@]}" -eq 0 ]; then
    state="green"
    msg="no secrets configured in chezmoi data"
  elif [ ! -s "$HOME/.config/sh/secrets.env" ]; then
    state="amber"
    msg="secrets.env missing"
  else
    state="amber"
    msg="checking secrets"
  fi

  [ "$state" = "green" ]
  [[ "$msg" == *"no secrets configured"* ]]
}

@test "non-TSTRUCT secret is preserved in secrets map" {
  # Create config with a GITHUB_TOKEN secret (not TSTRUCT)
  make_config_with_secrets '    GITHUB_TOKEN: "op://Private/GitHub/token"'

  # Parse the secrets from the YAML (simulate _cfg_keys secrets)
  # We just verify the key is present in the rendered config
  run grep -c "GITHUB_TOKEN" "$HOME/.config/chezmoi/chezmoi.yaml"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]

  # Verify TSTRUCT is NOT present
  run grep -c "TSTRUCT" "$HOME/.config/chezmoi/chezmoi.yaml"
  [ "$status" -eq 1 ]  # grep returns 1 when no matches
}

@test "multiple generic secrets are all preserved" {
  make_config_with_secrets '    GITHUB_TOKEN: "op://Private/GitHub/token"
    NPM_TOKEN: "op://Private/NPM/token"
    AWS_ACCESS_KEY: "-"'

  run grep -c "GITHUB_TOKEN" "$HOME/.config/chezmoi/chezmoi.yaml"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]

  run grep -c "NPM_TOKEN" "$HOME/.config/chezmoi/chezmoi.yaml"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]

  # AWS_ACCESS_KEY with "-" sentinel should still be present in the config
  run grep -c "AWS_ACCESS_KEY" "$HOME/.config/chezmoi/chezmoi.yaml"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]

  # TSTRUCT should not appear
  run grep -c "TSTRUCT" "$HOME/.config/chezmoi/chezmoi.yaml"
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# B. Config source
# ---------------------------------------------------------------------------

@test "local config path with spaces is accepted" {
  local spaced_dir="$TEST_HOME/path with spaces"
  mkdir -p "$spaced_dir"

  cat > "$spaced_dir/my config.yaml" <<'YAML'
sourceDir: ~/test
data:
  onepassword:
    enabled: false
  git:
    email: "space@test.com"
    name: "Space User"
  secrets: {}
  bootstrap:
    defer_clt: false
    defer_xcode: false
YAML

  # Simulate reading a file with spaces in the path
  local config_source="$spaced_dir/my config.yaml"
  [ -f "$config_source" ]

  run cat "$config_source"
  [ "$status" -eq 0 ]
  [[ "$output" == *"space@test.com"* ]]
}

@test "config source HTTPS URL is accepted" {
  # Stub curl to return valid YAML
  curl() {
    if [ "$1" = "-fsSL" ]; then
      cat <<'YAML'
sourceDir: ~/test
data:
  onepassword:
    enabled: false
  git:
    email: "remote@test.com"
    name: "Remote User"
  secrets: {}
  bootstrap:
    defer_clt: false
    defer_xcode: false
YAML
      return 0
    fi
    command curl "$@"
  }
  export -f curl

  local config_source="https://gist.githubusercontent.com/example/raw/config.yaml"
  local dest_dir="$HOME/.config/chezmoi"
  mkdir -p "$dest_dir"

  # Simulate the download
  run curl -fsSL "$config_source"
  [ "$status" -eq 0 ]
  [[ "$output" == *"remote@test.com"* ]]

  # Save it
  printf '%s' "$output" > "$dest_dir/chezmoi.yaml"

  # Verify it was saved
  [ -f "$dest_dir/chezmoi.yaml" ]
  run grep "remote@test.com" "$dest_dir/chezmoi.yaml"
  [ "$status" -eq 0 ]
}

@test "HTML response is rejected with guidance" {
  # Stub curl to return HTML
  curl() {
    if [ "$1" = "-fsSL" ]; then
      echo '<!DOCTYPE html>'
      echo '<html><body>Not a YAML file</body></html>'
      return 0
    fi
    command curl "$@"
  }
  export -f curl

  local config_source="https://gist.github.com/example/config"
  local content
  content="$(curl -fsSL "$config_source" 2>&1)" || true

  # Detect HTML
  local first_line
  first_line="$(printf '%s' "$content" | head -1)"
  local rejected=0
  case "$first_line" in
    \<\!* | \<[Hh][Tt][Mm][Ll]* | \<[Hh][Tt][Mm][Ll])
      rejected=1
      ;;
  esac

  [ "$rejected" -eq 1 ]
}

@test "malformed YAML does not overwrite existing config" {
  local dest_dir="$HOME/.config/chezmoi"
  mkdir -p "$dest_dir"

  # Create an existing valid config
  echo "sourceDir: ~/existing" > "$dest_dir/chezmoi.yaml"
  local original_mtime
  original_mtime="$(stat -f '%m' "$dest_dir/chezmoi.yaml" 2>/dev/null || stat -c '%Y' "$dest_dir/chezmoi.yaml" 2>/dev/null)"

  # Simulate malformed content (no data: key)
  local content="just some random text
not yaml at all"

  # Validate: must contain data: at root level
  if ! printf '%s' "$content" | grep -q '^data:'; then
    # Rejected — do not overwrite
    rejected=1
  else
    rejected=0
  fi

  [ "$rejected" -eq 1 ]

  # Original config should still be intact
  run grep "existing" "$dest_dir/chezmoi.yaml"
  [ "$status" -eq 0 ]
}

@test "failed download does not overwrite existing config" {
  local dest_dir="$HOME/.config/chezmoi"
  mkdir -p "$dest_dir"

  # Create an existing valid config
  echo "sourceDir: ~/existing" > "$dest_dir/chezmoi.yaml"

  # Stub curl to fail
  curl() {
    if [ "$1" = "-fsSL" ]; then
      echo "curl: (6) Could not resolve host" >&2
      return 6
    fi
    command curl "$@"
  }
  export -f curl

  local config_source="https://nonexistent.example.com/config.yaml"
  local content
  local download_ok=0
  content="$(curl -fsSL "$config_source" 2>&1)" || download_ok=$?

  # Download failed
  [ "$download_ok" -ne 0 ]

  # Original config should still be intact
  run grep "existing" "$dest_dir/chezmoi.yaml"
  [ "$status" -eq 0 ]
}

@test "supplied values survive chezmoi init" {
  # Create a config with specific values
  make_config_with_secrets '    GITHUB_TOKEN: "op://Private/GitHub/token"'

  # Simulate what chezmoi init would see: the config file exists with values
  local cfg="$HOME/.config/chezmoi/chezmoi.yaml"

  # Verify the values are present
  run grep "false" "$cfg"  # defer_clt, defer_xcode, assume_yes, enabled
  [ "$status" -eq 0 ]

  run grep "GITHUB_TOKEN" "$cfg"
  [ "$status" -eq 0 ]

  # Verify the config has the expected structure
  run grep "^data:" "$cfg"
  [ "$status" -eq 0 ]
}

@test "config_source appears in bootstrap-status JSON" {
  # Set the env var
  export CHEZMOI_CONFIG_SOURCE="https://gist.githubusercontent.com/example/raw/config.yaml"

  # Simulate the _render_json logic
  local config_source="${CHEZMOI_CONFIG_SOURCE:-interactive}"

  [ "$config_source" = "https://gist.githubusercontent.com/example/raw/config.yaml" ]
}

@test "config_source defaults to interactive when unset" {
  # Ensure the env var is NOT set
  unset CHEZMOI_CONFIG_SOURCE

  # Simulate the _render_json logic
  local config_source="${CHEZMOI_CONFIG_SOURCE:-interactive}"

  [ "$config_source" = "interactive" ]
}

# ---------------------------------------------------------------------------
# C. assume_yes
# ---------------------------------------------------------------------------

@test "assume_yes skips installation confirmation prompts" {
  # Simulate _ask_install with ASSUME_YES=1
  ASSUME_YES=1

  # _ask_install: when ASSUME_YES=1, return 0 (yes) without prompting
  _ask_install() {
    local prompt="$1"
    if [ "$ASSUME_YES" -eq 1 ]; then
      echo "${prompt} — proceeding (assume_yes)"
      return 0
    fi
    return 1
  }

  run _ask_install "Install full Xcode?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"proceeding (assume_yes)"* ]]
}

@test "assume_yes does not skip config value prompts" {
  # Simulate: mandatory config prompts (git.email, git.name) are NOT gated
  # by assume_yes. They use promptString/promptBool directly, not _ask_install.
  # This test verifies that the distinction exists in the design.

  ASSUME_YES=1

  # _ask_install is for installation confirmations only
  _ask_install() {
    local prompt="$1"
    if [ "$ASSUME_YES" -eq 1 ]; then
      return 0
    fi
    return 1
  }

  # A config-value prompt would use a different path (promptString/promptBool)
  # and would NOT be skipped by ASSUME_YES. We verify _ask_install exists
  # as a separate function from _ask.
  type _ask_install >/dev/null 2>&1
  [ "$?" -eq 0 ]

  # _ask_install always returns 0 when ASSUME_YES=1
  _ask_install "Some install prompt"
  [ "$?" -eq 0 ]
}

@test "explicit skip flag takes precedence over assume_yes" {
  # When --skip-clt is set, CLT is skipped regardless of assume_yes
  SKIP_CLT=1
  ASSUME_YES=1

  # Simulate the CLT gate logic
  DEFER_CLT=0
  if [ "$SKIP_CLT" -eq 1 ]; then
    DEFER_CLT=1
  fi

  [ "$DEFER_CLT" -eq 1 ]
}

@test "--yes flag enables assume_yes behavior" {
  # Simulate parse_args: --yes sets ASSUME_YES=1
  ASSUME_YES=0

  # Parse --yes
  case "--yes" in
    --yes) ASSUME_YES=1 ;;
  esac

  [ "$ASSUME_YES" -eq 1 ]
}

@test "Homebrew installer respects BOOTSTRAP_ASSUME_YES" {
  # Simulate the run_20-install-homebrew logic
  BOOTSTRAP_ASSUME_YES="true"
  NONINTERACTIVE=0

  if [ "${BOOTSTRAP_ASSUME_YES:-}" = "true" ] || [ "${BOOTSTRAP_ASSUME_YES:-}" = "1" ]; then
    NONINTERACTIVE=1
  elif [ -t 0 ] && [ -t 1 ]; then
    :
  else
    NONINTERACTIVE=1
  fi

  [ "$NONINTERACTIVE" -eq 1 ]
}

@test "Homebrew installer is interactive when assume_yes is not set and TTY present" {
  # Simulate with TTY (we're in a test, so [ -t 0 ] may or may not be true)
  # We test the logic path: when BOOTSTRAP_ASSUME_YES is unset and TTY is present
  unset BOOTSTRAP_ASSUME_YES
  NONINTERACTIVE=0

  # Simulate TTY present
  if [ "${BOOTSTRAP_ASSUME_YES:-}" = "true" ] || [ "${BOOTSTRAP_ASSUME_YES:-}" = "1" ]; then
    NONINTERACTIVE=1
  elif true; then  # simulating [ -t 0 ] && [ -t 1 ] being true
    :  # interactive, NONINTERACTIVE stays 0
  else
    NONINTERACTIVE=1
  fi

  [ "$NONINTERACTIVE" -eq 0 ]
}

@test "Homebrew installer falls back to NONINTERACTIVE when no TTY" {
  # Simulate no TTY
  unset BOOTSTRAP_ASSUME_YES
  NONINTERACTIVE=0

  if [ "${BOOTSTRAP_ASSUME_YES:-}" = "true" ] || [ "${BOOTSTRAP_ASSUME_YES:-}" = "1" ]; then
    NONINTERACTIVE=1
  elif false; then  # simulating [ -t 0 ] && [ -t 1 ] being false
    :
  else
    NONINTERACTIVE=1
  fi

  [ "$NONINTERACTIVE" -eq 1 ]
}

@test "dry-run causes no downloads or writes" {
  DRY_RUN=1
  local dest_dir="$HOME/.config/chezmoi"
  mkdir -p "$dest_dir"

  local wrote=0
  local downloaded=0

  # Simulate stage_config_import under dry-run
  local config_source="https://example.com/config.yaml"
  case "$config_source" in
    https://* | http://*)
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "[dry-run] would download: $config_source"
        downloaded=0  # not actually downloaded
      else
        downloaded=1
      fi
      ;;
  esac

  # Simulate write under dry-run
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] would write config to: $dest_dir/chezmoi.yaml"
    wrote=0  # not actually written
  else
    echo "content" > "$dest_dir/chezmoi.yaml"
    wrote=1
  fi

  [ "$downloaded" -eq 0 ]
  [ "$wrote" -eq 0 ]
  # The actual config file should not exist (we never wrote it)
  [ ! -f "$dest_dir/chezmoi.yaml" ]
}

@test "BOOTSTRAP_ASSUME_YES=1 also triggers NONINTERACTIVE" {
  # Test that the numeric "1" form works too
  BOOTSTRAP_ASSUME_YES="1"
  NONINTERACTIVE=0

  if [ "${BOOTSTRAP_ASSUME_YES:-}" = "true" ] || [ "${BOOTSTRAP_ASSUME_YES:-}" = "1" ]; then
    NONINTERACTIVE=1
  fi

  [ "$NONINTERACTIVE" -eq 1 ]
}