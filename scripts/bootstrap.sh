#!/bin/bash
# vim: set sw=4 et:
set -eu

function find_in_path {
    name=${1:-}
    if command -v "$name" &>/dev/null; then
        whereis -b "$name"
    else
        echo "$name: NOT_FOUND"
    fi
}


echo "invocation : $0 $*"
echo "whoami     : $(whoami)"
echo "pwd        : $(pwd)"
echo "uname      : $(uname -a)"

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

# docker login || true
# docker login -u "$DOCKER_IO_PULL_USERNAME" -p "$DOCKER_IO_PULL_PASSWORD" docker.io
# docker login -u "$QUAY_RHACS_ENG_RW_USERNAME" -p "$QUAY_RHACS_ENG_RW_PASSWORD" quay.io
