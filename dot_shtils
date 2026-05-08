#!/bin/sh

# Guard against multiple sourcing
[ -n "$_SHTILS_LOADED" ] && return 0
_SHTILS_LOADED=1

command_exists() {
	command -v "$1" > /dev/null 2>&1;
}

# pathmunge <dir> [after]: prepend (default) or append <dir> to PATH if absent.
pathmunge() {
	if ! echo "$PATH" | grep -Eq "(^|:)$1($|:)"; then
		if [ "${2}" = "after" ]; then
			PATH="${PATH}:${1}"
		else
			PATH="${1}:${PATH}"
		fi
	fi
}

# path_force_front <dir>: unconditionally move <dir> to the front of PATH,
# reordering if already present. Use when path_helper or a parent process
# may have placed entries in the wrong order.
path_force_front() {
	local _p=":${PATH}:"
	_p="${_p//:${1}:/:}"
	_p="${_p#:}"
	_p="${_p%:}"
	PATH="${1}${_p:+:${_p}}"
}

manual_pathmunge() {
	if ! echo "$MANPATH" | grep -Eq "(^|:)$1($|:)"; then
		if [ "${2}" = "after" ]; then
			MANPATH="${MANPATH}:${1}"
		else
			MANPATH="${1}:${MANPATH}"
		fi
	fi
}

info_pathmunge() {
	if ! echo "$INFOPATH" | grep -Eq "(^|:)$1($|:)"; then
		if [ "${2}" = "after" ]; then
			INFOPATH="${INFOPATH}:${1}"
		else
			INFOPATH="${1}:${INFOPATH}"
		fi
	fi
}

local_bin_dir="${HOME}/.local/bin"
if [ -d "$local_bin_dir" ]; then
	pathmunge "$local_bin_dir"
fi

# Echo helpers used by the venv suite. Defined as shell functions rather than
# delegated to the ~/.local/bin/echo-* binaries because `echo_run deactivate`
# and `echo_run . activate` need their args to run in the calling shell — a
# binary fork would lose the state change.
echo_run() {
	printf '\033[1;34m$ %s\033[0m\n' "$*" >&2
	"$@"
}

echo_info() {
	printf '\033[1;34m[INFO] --- %s\033[0m\n' "$*" >&2
}

echo_err() {
	printf '\033[1;31m[ERROR] --- %s\033[0m\n' "$*" >&2
}

# Python venv management.

novenv() {
	save_venv --quiet
	"$@"
	set -- $?
	restore_venv --quiet
	return "$1"
}

save_venv() {
	if [ "$VIRTUAL_ENV" = "" ]; then
		return
	fi

	if [ "${1:-}" != "--quiet" ]; then
		echo_info "Saving venv '${VIRTUAL_ENV}'."
	fi
	SAVED_VENVS="${VIRTUAL_ENV}:${SAVED_VENVS:-}"
	deactivate
}

restore_venv() {
	if command -v deactivate >/dev/null 2>&1; then
		echo_run deactivate
	fi

	if [ "${SAVED_VENVS:-}" != "" ]; then
		if [ "${1:-}" != "--quiet" ]; then
			echo_info "Restoring '${SAVED_VENVS%%:*}'."
		fi
		# shellcheck disable=SC1090,SC1091
		. "${SAVED_VENVS%%:*}/bin/activate"
		SAVED_VENVS="${SAVED_VENVS#${SAVED_VENVS%%:*}:}"
	fi
}

venv() {
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			echo "usage: $(basename "$0") [--create] [<venv name>]" >&2
			return
			;;
		--create | --create3)
			shift
			if [ "$VIRTUAL_ENV" != "" ]; then
				echo_run deactivate
			fi
			if [ -d "${1:-.venv}" ]; then
				echo_run rm -rf "${1:-.venv}"
			fi
			echo_run python3 -m venv "${1:-.venv}"
			echo_run . "${1:-.venv}/bin/activate"
			if [ -f requirements.txt ]; then
				echo_run pip install -r requirements.txt
			fi
			return $?
			;;
		*)
			break
			;;
		esac
		shift
	done

	# Recursively search up to $HOME for a venv with the desired name, so it
	# can be activated from anywhere within a project.
	set -- "${1:-.venv}" "$PWD" "$1"
	while [ "$2" != "$HOME" ] && [ "$2" != "/" ] && [ ! -f "${2}/${1}/bin/activate" ]; do
		set -- "$1" "$(dirname "$2")" "$3"
	done

	# If you're in a venv and you didn't specify a different one, deactivate
	# the current one.
	if [ "$VIRTUAL_ENV" != "" ] && [ "$3" = "" ]; then
		echo_run deactivate
		return
	fi

	if [ ! -f "${2}/${1}/bin/activate" ]; then
		echo_err "Couldn't find a valid venv for '${1}'"
		return 1
	fi

	# shellcheck disable=SC1090
	echo_run . "${2}/${1}/bin/activate"
}
