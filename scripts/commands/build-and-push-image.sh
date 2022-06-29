#!/bin/bash
set -eu
exit 1

docker_login() {
    # Login may be required for pulling the base image for building (if used)
    # and to circumvent the rate limit associated with unauthenticated access.
    docker login -u "$DOCKER_IO_PULL_USERNAME" -p "$DOCKER_IO_PULL_PASSWORD" docker.io
    docker login -u "$QUAY_RHACS_ENG_RW_USERNAME" -p "$QUAY_RHACS_ENG_RW_PASSWORD" quay.io
}

build_and_push_image() {
    if [[ -n "$BUILDS_ON" ]]; then
      BASE_TAG="$(.circleci/get_tag.sh "$BUILDS_ON")"
      BUILD_ARGS+=(--build-arg "BASE_TAG=$BASE_TAG")
    fi

    CENTOS_TAG="$(cat CENTOS_TAG)"
    BUILD_ARGS+=(--build-arg "CENTOS_TAG=${CENTOS_TAG}")

    BUILD_ARGS+=(--build-arg "ROCKSDB_TAG=$(.circleci/get_tag.sh rocksdb "${CENTOS_TAG}")")

    TAG="$(.circleci/get_tag.sh "$IMAGE_FLAVOR" "${CENTOS_TAG}")"
    IMAGE="quay.io/rhacs-eng/apollo-ci:${TAG}"

    if [[ "$IMAGE_FLAVOR" == "rocksdb" ]] && \
      DOCKER_CLI_EXPERIMENTAL=enabled docker manifest inspect "$IMAGE" >/dev/null; then
      echo "Image '$IMAGE' already exists - no need to build it"
      circleci step halt
      exit 0
    fi

    docker build \
      "${BUILD_ARGS[@]}" \
      -f "$DOCKERFILE_PATH" \
      -t "${IMAGE}" \
      images/

    for _ in {1..5}; do
      docker push "quay.io/rhacs-eng/apollo-ci:${TAG}" && break || sleep 15
    done

    for _ in {1..5}; do
      docker login -u "$QUAY_STACKROX_IO_RW_USERNAME" -p "$QUAY_STACKROX_IO_RW_PASSWORD" quay.io
      docker tag "${IMAGE}" "quay.io/stackrox-io/apollo-ci:${TAG}"
      docker push "quay.io/stackrox-io/apollo-ci:${TAG}" && break || sleep 15
    done
}


# __MAIN__
IMAGE_FLAVOR="${1:-none}"     # string -- a flavor used to tag the apollo-ci image
DOCKERFILE_PATH="${2:-none}"  # string -- path to the Dockerfile
BUILDS_ON="${3:-none}"        # string -- base image flavor on which to build

checkout
build_and_push_image
