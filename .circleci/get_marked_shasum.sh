#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <marker> <file>"
    exit 1
fi

marker="$1"
file="$2"
copy="$(mktemp)"
trap 'rm -f $copy' EXIT
cp "$file" "$copy"
printf "\n# %s" "$marker" >> "$copy"
read -r -a SHA < <(shasum "$copy")
echo "${SHA[0]}"
