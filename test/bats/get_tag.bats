#!/usr/bin/env bats

setup() {
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$DIR/../..:$PATH"
    CIRCLE_BRANCH=a-pr
    unset CIRCLE_TAG
    describe=$(git describe --tags --abbrev=10)
}

@test "expects an image flavor" {
  run scripts/get_tag.sh
  [ "$status" -eq 1 ]
}

@test "expects an image flavor value" {
  run scripts/get_tag.sh ""
  [ "$status" -eq 1 ]
}

@test 'appends git describe to flavor' {
  run scripts/get_tag.sh something
  [ "$status" -eq 0 ]
  [[ "$output" == "something-$describe" ]]
}
