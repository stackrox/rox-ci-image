#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <image flavor>"
    exit 1
fi

image_flavor="$1"

if [[ "$image_flavor" == "rocksdb" ]]; then
    echo "rocksdb-$(git hash-object images/centos8-rocksdb.Dockerfile)"
    exit 0
fi

if [[ "$image_flavor" == "rox" ]]; then
    image_prefix=""
else
    image_prefix="${image_flavor}-"
fi

echo "${image_prefix}$(git describe --tags --abbrev=10)"
