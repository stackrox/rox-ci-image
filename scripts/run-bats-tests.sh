#!/bin/bash
# Install bats (https://github.com/sstephenson/bats).
# Run bats tests.
set -eu

install_bats() {
    if command -v "bats" &>/dev/null; then
        local bats_path
        bats_path=$(whereis -b "bats")
        echo "Found bats at $bats_path"
    else
        echo "Installing bats"
        sudo apt-get -qq update -y >/dev/null
        sudo apt-get -qq install -y bats >/dev/null
    fi
}

assert_cwd_in_git_tree() {
    git describe --tags --abbrev=10 || {
        echo "ERROR: [$PWD] expected git repo"
        exit 1
    }
}


assert_cwd_in_git_tree
install_bats

bats --tap "./test/get_tag.bats" || {
    echo "ERROR: bats test failure"
    exit 1
}

bats --tap "./test/cci-export.bats" || {
    echo "ERROR: bats test failure"
    exit 1
}
