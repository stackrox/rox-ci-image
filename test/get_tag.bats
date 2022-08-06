#!/usr/bin/env bats

setup() {
  load "../third-party/bats-assert/load"
  load "../third-party/bats-support/load"
}

@test "expects an image-ident" {
  run ./scripts/get_tag.sh
  assert_failure
  assert_output --partial "invalid args"
  assert_output --partial "Usage"
}

@test "expects an image-ident to be non-empty" {
  run ./scripts/get_tag.sh ""
  assert_failure
  assert_output --partial "must be non-empty"
  assert_output --partial "Usage"
}

@test 'appends git describe to image-ident' {
  run ./scripts/get_tag.sh XYZ
  git_derived_tag=$(git describe --tags --abbrev=10)
  assert_success
  assert_output "XYZ-$git_derived_tag"
}

@test "expects a centos tag for rocksdb" {
  run ./scripts/get_tag.sh rocksdb
  assert_failure
  assert_output --partial "centos tag is required"
}

@test 'uses HASH for rocksdb' {
  local hash=$(git hash-object Dockerfile.rocksdb)
  run ./scripts/get_tag.sh "rocksdb" "stream99"
  assert_success
  assert_output "rocksdb-stream99-$hash"
}
