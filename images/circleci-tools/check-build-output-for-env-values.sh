#!/usr/bin/env bash

# When run in the context of an env-check image in a Circle CI job, this script
# will check the workflow build output for sensitive env values.

# Two environment variables are used to specify keys to ignore:
# SKIP_KEYS - skip any environment variables with keys that have these names
# SKIP_KEYS_RE - skip any environment variables with keys whose name matches these regexs
# multple values are separated by :

set -euo pipefail

if [[ -z "${CIRCLE_WORKFLOW_ID:-}" ]]; then
    echo "Not running under Circle CI"
    exit 1
fi

if [[ -n "${CIRCLE_TOKEN_ROXBOT:-}" ]]; then
    echo "Using the ROXBOT token for CircleCI token"
    export CIRCLECI_TOKEN="$CIRCLE_TOKEN_ROXBOT"
fi

if [[ -z "${CIRCLECI_TOKEN:-}" ]]; then
    echo "A Circle CI API token is required"
    exit 1
fi

poll-for-workflow-completion.js 1800

scratch="$(mktemp -d)"
output_dir="$scratch/builds"
mkdir -p "$output_dir"
pull-workflow-output.js "$output_dir"

env_file="$scratch/check.env"
env > "$env_file"

SKIP_KEYS="${SKIP_KEYS:-}"
IFS=":" read -r -a skip_keys <<< "$SKIP_KEYS"

SKIP_KEYS_RE="${SKIP_KEYS_RE:-}"
IFS=":" read -r -a skip_keys_re <<< "$SKIP_KEYS_RE"

check-for-sensitive-env-values.js -e "$env_file" -b "$output_dir" --skip "${skip_keys[@]}" --skip-re "${skip_keys_re[@]}"
rm "$env_file"
