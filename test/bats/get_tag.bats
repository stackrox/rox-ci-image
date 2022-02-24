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

@test 'omits flavor for rox' {
  run .circleci/get_tag.sh rox
  [ "$status" -eq 0 ]
  [[ "$output" == "$describe" ]]
}

@test 'uses HASH for rocksdb' {
  local hash="rocksdb-$(git hash-object images/centos8-rocksdb.Dockerfile)"
  run .circleci/get_tag.sh rocksdb
  [ "$status" -eq 0 ]
  [[ "$output" == "$hash" ]]
}
