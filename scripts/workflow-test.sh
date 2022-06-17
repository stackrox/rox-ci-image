#!/bin/bash
# This script was used for troublehooting initial GitHub CI workflows.
# It is a dependent of workflow-example.yml.
# Not sure either provide any sustained value at this point.
set -eu

function find_in_path {
    name=${1:-}
    if command -v "$name" &>/dev/null; then
        whereis -b "$name"
    else
        echo "$name: NOT_FOUND"
    fi
}

echo "invocation         : $0 $*"
echo "whoami             : $(whoami)"
echo "pwd                : $(pwd)"
echo "uname              : $(uname -a)"
echo "MOCK_SECRET        : $MOCK_SECRET"

expected="$(base64 -d <<<"$MOCK_SECRET")"
actual="$MOCK_SECRET_BASE64"
if [[ "$expected" != "$actual" ]]; then
    echo "ERROR: mismatch [$expected] != [$actual]"
fi

sudo apt-get update -y
sudo apt-get install -y bats

{
    find_in_path "docker"
    find_in_path "tree"
    find_in_path "git"
    find_in_path "gh"
    find_in_path "curl"
    find_in_path "bats"
    find_in_path "dig"
} | column -t
