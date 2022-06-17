#!/bin/bash
# vim: set sw=4 expandtab :
set -eu

docker_login() {
    echo "$QUAY_RHACS_ENG_RW_PASSWORD" \
        | docker login quay.io -u "$QUAY_RHACS_ENG_RW_USERNAME" --password-stdin
}

function image_manifest_exists {
    local image="$1"
    export DOCKER_CLI_EXPERIMENTAL=enabled
    docker manifest inspect "$image" >/dev/null || return 1
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
    IMAGE="quay.io/rhacs-eng/apollo-ci:${TAG}"

    echo "CMD              : [scripts/get_tag.sh "$IMAGE_TAG_PREFIX" "${CENTOS_TAG}"]"
    echo "TAG              : [$TAG]"
    echo "IMAGE            : [$IMAGE]"
    echo "IMAGE_TAG_PREFIX : [$IMAGE_TAG_PREFIX]"

    if [[ "$IMAGE_TAG_PREFIX" == "rocksdb" ]]; then
        if image_manifest_exists "$IMAGE"; then
            echo "Image '$IMAGE' already exists - no need to build it"
            exit 0
        fi
    fi

    docker build "${BUILD_ARGS[@]}" -f "$DOCKERFILE_PATH" -t "${IMAGE}" .

    for idx in {1..5}; do
        echo "docker push attempt $idx/5"
        docker push "${IMAGE}" && break || sleep 15
    done
}


# __MAIN__
DOCKERFILE_PATH="$1"   # string -- path to the Dockerfile
IMAGE_TAG_PREFIX="$2"  # string -- used to tag the image as a particular variant
BUILDS_ON="${3:-}"     # string -- base image variant on which to build

docker_login
build_and_push_image
