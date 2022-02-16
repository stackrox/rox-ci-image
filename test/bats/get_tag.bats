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

@test 'appends git describe' {
  run .circleci/get_tag.sh something
  [ "$status" -eq 0 ]
  [[ "$output" =~ $describe$ ]]
}

@test 'adds image flavor' {
  run .circleci/get_tag.sh something
  [ "$status" -eq 0 ]
  [[ "$output" == "snapshot-something-$describe" ]]
}

@test 'only adds image flavor when not ""' {
  run .circleci/get_tag.sh ""
  [ "$status" -eq 0 ]
  [[ "$output" == "snapshot-$describe" ]]
}

@test 'prepends snapshot on PRs' {
  export CIRCLE_BRANCH=a-pr
  run .circleci/get_tag.sh something
  [ "$status" -eq 0 ]
  [[ "$output" == "snapshot-something-$describe" ]]
}

@test 'does not prepend snapshot on master' {
  export CIRCLE_BRANCH=master
  run .circleci/get_tag.sh something
  [ "$status" -eq 0 ]
  [[ "$output" == "something-$describe" ]]
}

@test 'does not prepend snapshot on tags' {
  export CIRCLE_TAG=1.2.3
  run .circleci/get_tag.sh something
  [ "$status" -eq 0 ]
  [[ "$output" == "something-$describe" ]]
}

@test 'uses SHA for rocksdb' {
  local sha_tag="rocksdb-$(sha256sum images/rocksdb.Dockerfile | cut -f1 -d' ')"
  run .circleci/get_tag.sh rocksdb
  [ "$status" -eq 0 ]
  [[ "$output" == "$sha_tag" ]]
}
