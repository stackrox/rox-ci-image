#!/usr/bin/env bash
# Lookup env variables by name, and output "key: val" pairs to the terminal.
#
# Example:
#   ./test/env-var-printer.sh [--silent] VAR1 VAR2 ...
set -eo pipefail

function shell_is_zsh { [[ -n "${ZSH_VERSION:-}" ]]; }
function shell_is_bash { [[ -n "${BASH_VERSION:-}" ]]; }
function errcho { >&2 echo "$@"; }

function symtab_lookup {
  ident=$1

  if shell_is_zsh; then
    echo "${(P)ident}"
  elif shell_is_bash; then
    echo "${!ident}"
  fi
}


# __MAIN__
SILENT_MODE="false"
INPUTS=()

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    -s|--silent)
      SILENT_MODE="true"
      ;;
    *)
      INPUTS+=("$arg")
      ;;
  esac
done

# Iterate over inputs
for arg in "${INPUTS[@]}"; do
  if [[ "$SILENT_MODE" == "true" ]]; then
    echo "$(symtab_lookup $arg)"
  else
    echo "$arg: $(symtab_lookup $arg)"
  fi
done
