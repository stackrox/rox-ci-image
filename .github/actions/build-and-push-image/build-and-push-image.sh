#!/usr/bin/env bash

set -euo pipefail

build_and_push_image() {
    local image_flavor="$1"
    local target_arch="$2"
    local tag_suffix=""

    # Default to amd64 if no architecture specified (backward compatibility)
    if [ -z "${target_arch}" ]; then
        target_arch="amd64"
    else
        tag_suffix="-${target_arch}"
    fi

    docker login -u "$QUAY_STACKROX_IO_RW_USERNAME" --password-stdin <<<"$QUAY_STACKROX_IO_RW_PASSWORD" quay.io

    TAG="$(scripts/get_tag.sh "$image_flavor")${tag_suffix}"
    IMAGE="quay.io/stackrox-io/apollo-ci:${TAG}"

    make TARGETARCH="$target_arch" "$image_flavor"-image

    retry 5 true docker push "${IMAGE}"

    echo "image-tag=${IMAGE}" >> "${GITHUB_OUTPUT}"
}

# retry() - retry a command up to a specific numer of times until it exits
# successfully, with exponential back off.
# (original source: https://gist.github.com/sj26/88e1c6584397bb7c13bd11108a579746)

retry() {
    if [[ "$#" -lt 3 ]]; then
        die "usage: retry <try count> <delay true|false> <command> <args...>"
    fi

    local tries=$1
    local delay=$2
    shift; shift;

    local count=0
    until "$@"; do
        exit=$?
        wait=$((2 ** count))
        count=$((count + 1))
        if [[ $count -lt $tries ]]; then
            info "Retry $count/$tries exited $exit"
            if $delay; then
                info "Retrying in $wait seconds..."
                sleep $wait
            fi
            if [[ -n "${RETRY_HOOK:-}" ]]; then
                $RETRY_HOOK
            fi
        else
            echo "Retry $count/$tries exited $exit, no more retries left."
            return $exit
        fi
    done
    return 0
}

build_and_push_image "$@"
