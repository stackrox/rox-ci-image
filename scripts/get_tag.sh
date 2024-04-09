#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <image flavor> [<centos_tag>]"
    exit 1
fi

image_flavor="$1"

echo "${image_flavor}-$(git describe --tags --abbrev=10)"
