#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <image flavor> [<centos_tag>]"
    exit 1
fi

image_flavor="$1"

if [[ "$image_flavor" == "rocksdb" ]]; then
    if [[ -z "${2:-}" ]]; then
        echo "A centos tag is required for rocksdb"
        exit 1
    fi
    centos_tag="$2"
    echo "rocksdb-$centos_tag-$(git hash-object images/rocksdb.Dockerfile)"
    exit 0
fi

echo "${image_flavor}-$(git describe --tags --abbrev=10)"
