#!/usr/bin/env bash

set -euo pipefail

build_and_push_image() {
    local image_flavor="$1"

    # Login may be required for pulling the base image for building (if used) and to omit the rate limit
    docker login -u "$QUAY_RHACS_ENG_RW_USERNAME" --password-stdin <<<"$QUAY_RHACS_ENG_RW_PASSWORD" quay.io

    make "$image_flavor"-image

    STACKROX_CENTOS_TAG="$(cat STACKROX_CENTOS_TAG)"
    TAG="$(scripts/get_tag.sh "$image_flavor" "${STACKROX_CENTOS_TAG}")"
    IMAGE="quay.io/rhacs-eng/apollo-ci:${TAG}"

    if [[ "$image_flavor" == "rocksdb" ]]; then
        # The rocksdb image might not exist locally if make decided to skip it.
        # Pull it in order to push with retag later.
        for _ in {1..5}; do
            docker pull "${IMAGE}" && break
            sleep 15
        done
    fi

    for _ in {1..5}; do
        docker push "${IMAGE}" && break
        sleep 15
    done

    for _ in {1..5}; do
        docker login -u "$QUAY_STACKROX_IO_RW_USERNAME" --password-stdin <<<"$QUAY_STACKROX_IO_RW_PASSWORD" quay.io
        docker tag "${IMAGE}" "quay.io/stackrox-io/apollo-ci:${TAG}"
        docker push "quay.io/stackrox-io/apollo-ci:${TAG}" && break
        sleep 15
    done
}

build_and_push_image "$@"
