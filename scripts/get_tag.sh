#!/usr/bin/env bash
# This script determines what tags are use for the built images.
#
# ./.circleci/get_tag.sh             -> ERROR: invalid args
# ./.circleci/get_tag.sh ""          -> ERROR: invalid args
# ./.circleci/get_tag.sh foo         -> foo-0.3.42-105-g95a23d2007
# ./.circleci/get_tag.sh bar         -> bar-0.3.42-105-g95a23d2007
# ./.circleci/get_tag.sh rocksdb     -> ERROR: centos tag required
# ./.circleci/get_tag.sh rocksdb xyz -> rocksdb-xyz-41b9acc72366bdbaf892ba30979ee20e27a36a6a
set -eu

function die {
    if [[ $# -gt 0 ]]; then
        echo "$@"
        echo
    fi
    echo "Usage: $0 <image-ident> [<centos_tag>]"
    exit 1
}


# __MAIN__
[[ $# -ge 1 ]] || die "invalid args to script"

image_ident="$1"  # stackrox | scanner | collector | rocksdb | ...
centos_tag="${2:-}"

if [[ "$image_ident" == "rocksdb" ]]; then
    [[ -n "${centos_tag:-}" ]] \
        || die "A centos tag is required for rocksdb"
    rocks_db_dockerfile_obj_hash="$(git hash-object Dockerfile.rocksdb)"
    echo "$image_ident-$centos_tag-${rocks_db_dockerfile_obj_hash}"
else
    [[ -n ${image_ident} ]] \
        || die "image-ident must be non-empty"
    git_derived_tag="$(git describe --tags --abbrev=10)"
    echo "${image_ident}-${git_derived_tag}"
fi

exit 0
