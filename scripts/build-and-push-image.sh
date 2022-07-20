#!/bin/bash
# vim: set sw=4 expandtab :
set -eu

docker_login_quay_rhacs_eng() {
    echo "$QUAY_RHACS_ENG_RW_PASSWORD" \
        | docker login quay.io -u "$QUAY_RHACS_ENG_RW_USERNAME" --password-stdin
}

docker_login_quay_stackrox_io() {
    echo "$QUAY_STACKROX_IO_RW_PASSWORD" \
        | docker login quay.io -u "$QUAY_STACKROX_IO_RW_USERNAME" --password-stdin
}

image_manifest_exists() {
    local image="$1"
    export DOCKER_CLI_EXPERIMENTAL=enabled
    docker manifest inspect "$image" >/dev/null || return 1
}

docker_push_with_retry() {
    local image="$1"
    local tries="${2:-5}"

    for idx in $(seq $tries); do
        echo "docker push attempt $idx/$tries"
        docker push "$image" && break || sleep 15
    done
}

build_and_push_image() {
    if [[ -n "$BUILDS_ON" ]]; then
        BASE_TAG="$(scripts/get_tag.sh "$BUILDS_ON")"
        BUILD_ARGS+=(--build-arg "BASE_TAG=$BASE_TAG")
    fi

    CENTOS_TAG="$(cat config/CENTOS_TAG)"
    BUILD_ARGS+=(--build-arg "CENTOS_TAG=${CENTOS_TAG}")
    BUILD_ARGS+=(--build-arg "ROCKSDB_TAG=$(scripts/get_tag.sh rocksdb "${CENTOS_TAG}")")

    TAG="$(scripts/get_tag.sh "$IMAGE_TAG_PREFIX" "${CENTOS_TAG}")"
    RHACS_ENG_IMAGE="quay.io/rhacs-eng/apollo-ci:${TAG}"
    STACKROX_IO_IMAGE="quay.io/stackrox-io/apollo-ci:${TAG}"

    echo "CMD                : [scripts/get_tag.sh "$IMAGE_TAG_PREFIX" "${CENTOS_TAG}"]"
    echo "TAG                : [$TAG]"
    echo "RHACS_ENG_IMAGE    : [$RHACS_ENG_IMAGE]"
    echo "STACKROX_IO_IMAGE  : [$STACKROX_IO_IMAGE]"
    echo "IMAGE_TAG_PREFIX   : [$IMAGE_TAG_PREFIX]"

    if [[ "$IMAGE_TAG_PREFIX" == "rocksdb" ]]; then
        if image_manifest_exists "$RHACS_ENG_IMAGE"; then
            echo "Image '$RHACS_ENG_IMAGE' already exists - no need to build it"
            exit 0
        fi
    fi

    docker_login_quay_rhacs_eng
    docker build "${BUILD_ARGS[@]}" -f "$DOCKERFILE_PATH" -t "$RHACS_ENG_IMAGE" .
    docker_push_with_retry "$RHACS_ENG_IMAGE"

    docker_login_quay_stackrox_io
    docker tag "$RHACS_ENG_IMAGE" "$STACKROX_IO_IMAGE"
    docker_push_with_retry "$STACKROX_IO_IMAGE"
}


# __MAIN__
DOCKERFILE_PATH="$1"   # string -- path to the Dockerfile
IMAGE_TAG_PREFIX="$2"  # string -- used to tag the image as a particular variant
BUILDS_ON="${3:-}"     # string -- base image variant on which to build

build_and_push_image
