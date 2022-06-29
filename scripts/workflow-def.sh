#!/bin/bash
set -eu
exit 1

  build:
    jobs:
    - bats/run:
        path: ./test/bats
        filters:
          tags:
            only: /.*/
          branches:
            ignore: shane/rs-525-ci-migration
    - build-and-push-rocksdb:
        context: &buildPushContext
          - quay-rhacs-eng-readwrite
          - docker-io-pull
        filters:
          tags:
            only: /.*/
          branches:
            ignore: shane/rs-525-ci-migration
        requires:
        - bats/run
    - build-and-push-stackrox-build:
        context: &buildPushCheckContext
          - quay-rhacs-eng-readwrite
          - quay-stackrox-io-readwrite
          - stackrox-ci-instance
          - docker-io-pull
        filters:
          tags:
            only: /.*/
          branches:
            ignore: shane/rs-525-ci-migration
        requires:
        - build-and-push-rocksdb
    - build-and-push-stackrox-test:
        context:
          *buildPushCheckContext
        filters:
          tags:
            only: /.*/
          branches:
            ignore: shane/rs-525-ci-migration
        requires:
        - build-and-push-stackrox-build
    - build-and-push-stackrox-test-cci:
        context:
          *buildPushCheckContext
        filters:
          tags:
            only: /.*/
          branches:
            ignore: shane/rs-525-ci-migration
        requires:
        - build-and-push-stackrox-test
    - test-cci-export:
        context: quay-rhacs-eng-readonly
        filters:
          tags:
            only: /.*/
          branches:
            ignore: shane/rs-525-ci-migration
        requires:
        - build-and-push-stackrox-test-cci
    - build-and-push-collector:
        context:
          *buildPushCheckContext
        filters:
          tags:
            only: /.*/
          branches:
            ignore: shane/rs-525-ci-migration
        requires:
        - bats/run
    - build-and-push-scanner-build:
        context: &buildPushCheckContext
          - quay-rhacs-eng-readwrite
          - quay-stackrox-io-readwrite
          - stackrox-ci-instance
          - docker-io-pull
        filters:
          tags:
            only: /.*/
          branches:
            ignore: shane/rs-525-ci-migration
        requires:
        - bats/run
    - build-and-push-scanner-test:
        context:
          *buildPushCheckContext
        filters:
          tags:
            only: /.*/
          branches:
            ignore: shane/rs-525-ci-migration
        requires:
        - build-and-push-scanner-build
    - build-and-push-scanner-test-cci:
        context:
          *buildPushCheckContext
        filters:
          tags:
            only: /.*/
          branches:
            ignore: shane/rs-525-ci-migration
        requires:
        - build-and-push-scanner-test
    - build-and-push-jenkins-plugin:
        context:
          *buildPushCheckContext
        filters:
          tags:
            only: /.*/
          branches:
            ignore: shane/rs-525-ci-migration
        requires:
        - bats/run
    - create-or-update-collector-repo-pr:
        filters:
          branches:
            ignore: master
        requires:
        - build-and-push-collector
    - create-or-update-stackrox-repo-pr:
        filters:
          branches:
            ignore: master
        requires:
        - build-and-push-stackrox-build
        - build-and-push-stackrox-test-cci
    - create-or-update-scanner-repo-pr:
        filters:
          branches:
            ignore: master
        requires:
        - build-and-push-scanner-build
        - build-and-push-scanner-test-cci
    - create-or-update-jenkins-plugin-repo-pr:
        filters:
          branches:
            ignore: master
        requires:
        - build-and-push-jenkins-plugin

