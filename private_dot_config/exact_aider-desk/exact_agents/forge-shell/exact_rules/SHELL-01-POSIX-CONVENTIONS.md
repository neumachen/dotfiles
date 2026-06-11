# Shell Rule: POSIX-First Conventions

When writing shell scripts, default to POSIX `sh`. Reach for Bash only when a POSIX equivalent does not exist or would be meaningfully worse. Document the choice when you make it.

## Choosing the shell

| Situation | Use |
|---|---|
| Init scripts, container entrypoints, system glue running where `bash` may not exist (Alpine, distroless, BSD, minimal containers) | `sh` (POSIX) — `#!/bin/sh` |
| Build scripts, CI helpers, dev tools running on a known host with bash installed | `bash` — `#!/usr/bin/env bash` |
| Anything more than ~200 lines or anything with non-trivial data structures | switch to Python, Go, or another real language — shell is the wrong tool |

Always specify the interpreter via shebang. Never rely on the user's login shell.

## Strict mode

For both `sh` and `bash`, the first non-shebang lines are:

```sh
#!/bin/sh
set -eu        # POSIX. Add `-x` during debugging.
# Or for bash:
#!/usr/bin/env bash
set -Eeuo pipefail
```

- `-e` — exit on unhandled error.
- `-u` — error on unset variable. Reference `${var:-default}` if a variable may legitimately be unset.
- `-o pipefail` (bash) — fail a pipeline if any stage fails, not just the last. POSIX has no equivalent; check `$?` of intermediate commands manually if needed.
- `-E` (bash) — propagate `ERR` traps into functions and subshells. Required for `trap '...' ERR` to work correctly.

When a command can legitimately fail and you handle it, suppress `-e` for that command only:

```sh
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found, using awk fallback" >&2
fi
```

Not:

```sh
set +e
command -v jq
status=$?
set -e
```

## POSIX vs Bash

These are common Bash-only features. Avoid in POSIX scripts; use them freely in Bash scripts.

| Feature | POSIX | Bash | POSIX alternative |
|---|---|---|---|
| `[[ x = y ]]` | ✗ | ✓ | `[ "$x" = "$y" ]` |
| `(( i++ ))` arithmetic | ✗ | ✓ | `i=$((i + 1))` |
| `${var,,}` / `${var^^}` case change | ✗ | ✓ | `tr '[:upper:]' '[:lower:]'` |
| `${var//pat/repl}` substring replace | ✗ | ✓ | `sed` / `awk` |
| Arrays `arr=(a b c)` | ✗ | ✓ | Positional params or newline-delimited strings |
| `=~` regex match | ✗ | ✓ | `expr "$var" : 'pattern'`, `grep -E -q` |
| `<<<"$var"` here-string | ✗ | ✓ | `printf '%s\n' "$var" \| cmd` |
| Process substitution `<(cmd)` | ✗ | ✓ | Named pipe (`mkfifo`) — usually means "use Bash" |
| `source` keyword | ✗ | ✓ | `.` (dot) — works in both, prefer for POSIX |
| `function name() {}` | ✗ | ✓ | `name() { ...; }` — works in both, prefer for POSIX |

## Quoting

- Quote every variable expansion. `$var` unquoted word-splits and glob-expands; that's almost never what you want.
- Use double quotes for interpolation, single quotes when no interpolation is needed.
- Quote command substitutions too: `"$(cmd)"`, not `$(cmd)`.
- `"$@"` for "all arguments, individually quoted" (correct). `"$*"` for "all arguments joined by IFS" (rarely what you want). `$@` and `$*` unquoted are always wrong.

```sh
# Good
for f in "$@"; do
  cp -- "$f" "$dest/"
done

# Bad — breaks on filenames with spaces
for f in $@; do
  cp $f $dest/
done
```

## Filenames and `--`

- Use `--` as the end-of-options sentinel before filenames in any command that accepts options:
  ```sh
  rm -- "$file"             # protects against filenames starting with -
  cp -- "$src" "$dst"
  ```
- Use `./` prefix on local files when the name might start with `-`: `cp -- "./$file" ...`.
- Filenames with newlines are valid POSIX. Defensive scripts use `-print0` / `read -d ''` style. Pragmatic scripts document the assumption "no newlines in filenames."

## Variables

- `local` is Bash, ksh, dash (recent), and zsh — **not POSIX**. In strict POSIX, use a subshell `(...)` to scope variables, or accept module-level scope.
- Constants: `readonly NAME=value` (POSIX) — use over uppercase convention alone.
- Avoid uppercase for non-environment variables — uppercase is reserved for env vars and a few shell built-ins (`PATH`, `HOME`).
- `IFS` resets: if you modify `IFS`, restore it. The safe-restore pattern in POSIX:
  ```sh
  oIFS=$IFS
  IFS=':'
  for path in $PATH; do ...; done
  IFS=$oIFS
  ```

## Conditionals

- `test EXPR` and `[ EXPR ]` are POSIX. `[[ EXPR ]]` is Bash/ksh/zsh.
- String comparison: `=` (not `==` — `==` is non-POSIX).
- Numeric comparison: `-eq`, `-ne`, `-lt`, `-le`, `-gt`, `-ge` inside `[ ]`. Or `[ "$((a + b))" -gt 0 ]`.
- Empty/non-empty: `[ -z "$x" ]` (empty), `[ -n "$x" ]` (non-empty).
- File tests: `[ -f path ]`, `[ -d path ]`, `[ -e path ]` (exists, any type), `[ -r path ]`, `[ -w path ]`, `[ -x path ]`.

## Loops

- `for x in $list` word-splits on `IFS` — useful for `$@` and similar.
- Reading lines: `while IFS= read -r line; do ...; done < file`.
- C-style `for ((i=0; i<n; i++))` is Bash-only. POSIX equivalent: `i=0; while [ $i -lt "$n" ]; do ...; i=$((i + 1)); done`.

## Functions

- POSIX function definition: `name() { command; ...; }`. Avoid `function` keyword (Bash-only).
- Return value via `return N` where N is 0–255. Return data via stdout or globals.
- Document each function with a short comment explaining inputs (`$1`, `$2`, ...) and outputs (stdout, side effects).

```sh
# slugify <string> -> stdout
slugify() {
  printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -e 's/^-//' -e 's/-$//'
}
```

## Errors and traps

- Trap on `EXIT` for cleanup. Works in POSIX:
  ```sh
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT INT TERM
  ```
- Bash supports `trap '...' ERR` (with `set -E` for inheritance into functions). POSIX has no `ERR` trap.
- Write errors to stderr: `echo "error: ..." >&2`. Never to stdout.
- `die() { echo "fatal: $*" >&2; exit 1; }` is a useful POSIX helper.

## Subprocesses and pipes

- Subshells `( ... )` for grouping with environment isolation. Variable changes inside don't leak out.
- `cmd1 | cmd2` runs `cmd1` and `cmd2` in subshells (most shells). Variables assigned in the right-hand side of a pipe don't survive in POSIX `sh` and POSIX-mode `bash`. Workaround:
  ```sh
  # process-substitution friendly (bash):
  while read -r line; do x="$line"; done < <(cmd)

  # POSIX:
  result=$(cmd | awk '...')
  ```
- `cmd >/dev/null 2>&1` to discard both. POSIX. `&>` is Bash-only.

## Heredocs

```sh
cat <<EOF
literal $var expansion
EOF

cat <<'EOF'
no $var expansion
EOF

cat <<-EOF
	leading tabs stripped (note: tabs, not spaces)
EOF
```

Quote the delimiter (`'EOF'`) to suppress variable expansion. Indent with the `-` form **only with tab indentation** — spaces are not stripped.

## External commands

- Prefer shell built-ins (`printf`, `read`, `[`, parameter expansion) over fork-exec'ing `echo`, `grep`, `awk` for trivial operations.
- `printf '%s\n' "$x"` over `echo "$x"` — `echo` interprets `-n`, `\n`, and the like inconsistently across shells. `printf` is portable.
- Cache expensive command output in a variable instead of calling repeatedly.

## Idempotency

Scripts that may run more than once (setup scripts, CI helpers) should be idempotent:

- `mkdir -p` not `mkdir` (succeeds if dir exists).
- `rm -f` not `rm` (succeeds if file is absent).
- Check before installing: `command -v jq >/dev/null 2>&1 || install_jq`.
- Use `--needed`-style flags where the package manager supports them.

## shellcheck

- `shellcheck` clean before commit. No `# shellcheck disable=...` without a single-line comment justifying the exception.
- Add `.shellcheckrc` at the repo root to set the default shell (`shell=sh` or `shell=bash`) so individual scripts don't need a `# shellcheck shell=...` directive.

```ini
# .shellcheckrc
shell=sh
external-sources=true
```

- Common `# shellcheck` directives:
  - `# shellcheck source=path/to/file` — tell shellcheck where a `.`-sourced file lives.
  - `# shellcheck disable=SC1090` — only when shellcheck can't follow a dynamic source path AND you've reviewed the file by hand.

## Anti-patterns

- `cat file | grep x` — useless cat. `grep x file`.
- `[ $x = "y" ]` — unquoted, breaks on empty/spaced `$x`. `[ "$x" = "y" ]`.
- `eval "$user_input"` — almost always wrong. If you think you need it, reach for a real language.
- Parsing `ls` — newline-delimited filenames are valid. Use `find -print0` + `xargs -0`, or shell globbing.
- `for f in $(ls)` — see above.
- `cmd && cmd` as a substitute for control flow — fine for single steps, becomes unreadable when chained beyond 3.

## Examples

### Good — POSIX script with cleanup

```sh
#!/bin/sh
set -eu

usage() {
  cat <<EOF
Usage: $0 [-h] -i FILE -o DIR

  -i  input file
  -o  output directory
  -h  show this help
EOF
}

die() { echo "fatal: $*" >&2; exit 1; }

input=
out=
while getopts ":hi:o:" opt; do
  case "$opt" in
    h) usage; exit 0 ;;
    i) input=$OPTARG ;;
    o) out=$OPTARG ;;
    :) die "option -$OPTARG requires an argument" ;;
    ?) die "unknown option -$OPTARG" ;;
  esac
done

[ -n "$input" ] || die "missing -i"
[ -n "$out" ]   || die "missing -o"
[ -f "$input" ] || die "input not found: $input"

mkdir -p -- "$out"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

cp -- "$input" "$tmp/work"
# ... do work ...
mv -- "$tmp/work" "$out/result"
```

### Bad

```sh
# no shebang, no quoting, parsing ls, unquoted $@:
set -e
INPUT=$1
for f in `ls $INPUT/*.txt`; do
  cat $f | grep error > $INPUT/$(basename $f).err
done
```
