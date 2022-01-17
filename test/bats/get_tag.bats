setup() {
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$DIR/../..:$PATH"
}

@test "expects an image flavor" {
  run .circleci/get_tag.sh
  [ "$status" -eq 1 ]
}

@test 'image flavor can be ""' {
  run .circleci/get_tag.sh ""
  [ "$status" -eq 0 ]
}

@test 'image flavor can be something' {
  run .circleci/get_tag.sh something
  [ "$status" -eq 0 ]
}

@test 'uses git describe' {
  describe=$(git describe --tags --abbrev=10)
  run .circleci/get_tag.sh something
  [ "$status" -eq 0 ]
  [[ "$output" =~ $describe$ ]]
}

@test 'adds image flavor' {
  describe=$(git describe --tags --abbrev=10)
  run .circleci/get_tag.sh something
  [ "$status" -eq 0 ]
  [[ "$output" =~ something-$describe$ ]]
}

@test 'only adds image flavor when not ""' {
  describe=$(git describe --tags --abbrev=10)
  run .circleci/get_tag.sh ""
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^snapshot-$describe$ ]]
}

@test 'prepends snapshot' {
  describe=$(git describe --tags --abbrev=10)
  run .circleci/get_tag.sh something
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^snapshot-something-$describe$ ]]
}

@test 'does not prepend snapshot on master' {
  describe=$(git describe --tags --abbrev=10)
  export CIRCLE_BRANCH=master
  run .circleci/get_tag.sh something
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^something-$describe$ ]]
}

@test 'does not prepend snapshot on tags' {
  describe=$(git describe --tags --abbrev=10)
  export CIRCLE_TAG=1.2.3
  run .circleci/get_tag.sh something
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^something-$describe$ ]]
}
