#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <image flavor>"
    exit 1
fi

image_flavor="$1"
if [[ "$image_flavor" != "" ]]; then
    image_flavor="${image_flavor}-"
fi

snapshot=""
if [[ "${CIRCLE_BRANCH:-}" != "master" ]]; then
    snapshot="snapshot-"
fi

echo "${snapshot}${image_flavor}$(git describe --tags --abbrev=10)"
