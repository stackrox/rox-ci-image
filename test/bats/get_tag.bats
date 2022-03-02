#!/usr/bin/env bats

setup() {
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$DIR/../..:$PATH"
    CIRCLE_BRANCH=a-pr
    unset CIRCLE_TAG
    describe=$(git describe --tags --abbrev=10)
}

@test "expects an image flavor" {
  run .circleci/get_tag.sh
  [ "$status" -eq 1 ]
}

@test "expects an image flavor value" {
  run .circleci/get_tag.sh ""
  [ "$status" -eq 1 ]
}

@test 'appends git describe to flavor' {
  run .circleci/get_tag.sh something
  [ "$status" -eq 0 ]
  [[ "$output" == "something-$describe" ]]
}

@test "expects a centos tag for rocksdb" {
  run .circleci/get_tag.sh rocksdb
  [ "$status" -eq 1 ]
}

@test 'uses HASH for rocksdb' {
  local hash=$(git hash-object images/rocksdb.Dockerfile)
  run .circleci/get_tag.sh rocksdb stream99
  [ "$status" -eq 0 ]
  [[ "$output" == "rocksdb-stream99-$hash" ]]
}
