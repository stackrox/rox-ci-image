#!/bin/bash
set -eu
exit 1

jobs:
  build-and-push-rocksdb:
    <<: *defaults
    steps:
      - build-and-push-image:
          dockerfile-path: images/rocksdb.Dockerfile
          image-flavor: "rocksdb"

  build-and-push-stackrox-build:
    <<: *defaults
    steps:
      - build-and-push-image:
          dockerfile-path: images/stackrox-build.Dockerfile
          image-flavor: "stackrox-build"
      - check-image:
          image-flavor: "stackrox-build"

  build-and-push-stackrox-test:
    <<: *defaults
    steps:
      - build-and-push-image:
          dockerfile-path: images/stackrox-test.Dockerfile
          image-flavor: "stackrox-test"
          builds-on: "stackrox-build"
      - check-image:
          image-flavor: "stackrox-test"

  build-and-push-stackrox-test-cci:
    <<: *defaults
    steps:
      - build-and-push-image:
          dockerfile-path: images/circleci.Dockerfile
          image-flavor: "stackrox-test-cci"
          builds-on: "stackrox-test"
      - check-image:
          image-flavor: "stackrox-test-cci"

  test-cci-export:
    <<: *defaults
    resource_class: medium
    steps:
    - checkout
    - setup_remote_docker
    - run:
        name: Test cci-export inside Docker
        command: |
          docker login -u "$QUAY_RHACS_ENG_RO_USERNAME" --password-stdin \<<<"$QUAY_RHACS_ENG_RO_PASSWORD" quay.io
          BASE_TAG="$(.circleci/get_tag.sh stackrox-test-cci)"

          docker build \
            --build-arg BASE_TAG="$BASE_TAG" \
            -f images/test.cci-export.Dockerfile \
            -t test.cci-export \
            images/
          docker run --rm test.cci-export

  build-and-push-collector:
    <<: *defaults
    steps:
      - build-and-push-image:
          dockerfile-path: images/collector.Dockerfile
          image-flavor: "collector"
      - check-image:
          image-flavor: "collector"

  build-and-push-scanner-build:
    <<: *defaults
    steps:
      - build-and-push-image:
          dockerfile-path: images/scanner-build.Dockerfile
          image-flavor: "scanner-build"
      - check-image:
          image-flavor: "scanner-build"

  build-and-push-scanner-test:
    <<: *defaults
    steps:
      - build-and-push-image:
          dockerfile-path: images/scanner-test.Dockerfile
          image-flavor: "scanner-test"
          builds-on: "scanner-build"
      - check-image:
          image-flavor: "scanner-test"

  build-and-push-scanner-test-cci:
    <<: *defaults
    steps:
      - build-and-push-image:
          dockerfile-path: images/circleci.Dockerfile
          image-flavor: "scanner-test-cci"
          builds-on: "scanner-test"
      - check-image:
          image-flavor: "scanner-test-cci"

  build-and-push-jenkins-plugin:
    <<: *defaults
    steps:
      - build-and-push-image:
          dockerfile-path: images/jenkins-plugin.Dockerfile
          image-flavor: "jenkins-plugin"
      - check-image:
          image-flavor: "jenkins-plugin"

  create-or-update-stackrox-repo-pr:
    <<: *defaults
    steps:
      - open-test-pr:
          repo: stackrox
          labels: "ci-upgrade-tests"
          image-flavors: "stackrox-build,stackrox-test-cci,stackrox-test"

  create-or-update-scanner-repo-pr:
    <<: *defaults
    steps:
      - open-test-pr:
          repo: scanner
          labels: "generate-dumps-on-pr"
          image-flavors: "scanner-build,scanner-test-cci,scanner-test"

  create-or-update-collector-repo-pr:
    <<: *defaults
    steps:
      - open-test-pr:
          repo: collector
          image-flavors: "collector"

  create-or-update-jenkins-plugin-repo-pr:
    <<: *defaults
    steps:
      - open-test-pr:
          repo: jenkins-plugin
          image-flavors: "jenkins-plugin"

