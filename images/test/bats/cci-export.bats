#!/usr/bin/env bats

# To run the test locally do:
# docker build -t apollo-cci:test -f images/test.cci-export.Dockerfile images && docker run -it apollo-cci:test

bats_helpers_root="/usr/lib/node_modules"
load "${bats_helpers_root}/bats-support/load.bash"
load "${bats_helpers_root}/bats-assert/load.bash"

setup() {
  bash_env="$(mktemp)"
  export BASH_ENV="$bash_env"
  # ensure clean start of every test case
  unset FOO
  echo "" > "$bash_env"
  run echo $BASH_ENV
  assert_output "$bash_env"
  run cat $BASH_ENV
  assert_output ""
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: "
}

@test "cci-export BASH_ENV does not exist" {
  run rm -f "${BASH_ENV}"
  run test -f "${BASH_ENV}"
  assert_failure

  run cci-export FOO cci1
  assert_success
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: cci1"
  refute_output "FOO: "
}

@test "cci-export sanity check single value" {
  run cci-export FOO cci1
  assert_success
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: cci1"
  refute_output "FOO: "

  run cci-export FOO cci2
  assert_success
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: cci2"
  refute_output "FOO: cci1"
}

@test "cci-export should escape special characters in values" {
  run cci-export FOO 'quay.io/rhacs-"eng"/super scanner:2.21.0-15-{{g44}(8f)2dc8fa}'
  assert_success
  run "$HOME/test/foo-printer.sh"
  assert_output 'FOO: quay.io/rhacs-"eng"/super scanner:2.21.0-15-{{g44}(8f)2dc8fa}'
  refute_output "FOO: "
}

@test "cci-export sanity check many values" {
  export _FILE="$HOME/test/bats/FILE"
  run cat "${_FILE}"
  assert_output "1.2.3"

  export VAR=placeholder
  run cci-export VAR1 "text/$VAR/text:$(cat "${_FILE}")"
  run cci-export VAR2 "text/$VAR/text:$(cat "${_FILE}")"
  run cci-export IMAGE3 "text/$VAR/text:$(cat "${_FILE}")"

  run "$HOME/test/foo-printer.sh" "VAR1"
  assert_output "VAR1: text/$VAR/text:$(cat "${_FILE}")"
  assert_output "VAR1: text/placeholder/text:1.2.3"

  run "$HOME/test/foo-printer.sh" VAR2
  assert_output "VAR2: text/$VAR/text:$(cat "${_FILE}")"
  assert_output "VAR2: text/placeholder/text:1.2.3"

  run "$HOME/test/foo-printer.sh" IMAGE3
  assert_output "IMAGE3: text/$VAR/text:$(cat "${_FILE}")"
  assert_output "IMAGE3: text/placeholder/text:1.2.3"
}

@test "cci-export potentially colliding variable names" {
  run cci-export PART1 "value1"
  run cci-export PART1_PART2 "value_joined"
  run cci-export PART1 "value2"

  run "$HOME/test/foo-printer.sh" PART1
  assert_output "PART1: value2"
  refute_output "PART1: value1"
  run "$HOME/test/foo-printer.sh" PART1_PART2
  assert_output "PART1_PART2: value_joined"
}

@test "exported variable should be respected in a script" {
  export FOO=bar
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: bar"
  refute_output "FOO: "
}

@test "shadowed variable should be respected in a script" {
  FOO=bar run "$HOME/test/foo-printer.sh"
  assert_output "FOO: bar"
  refute_output "FOO: "
}

@test "exported variable should have priority over the cci-exported one" {
  run cci-export FOO cci
  export FOO=bar
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: bar"
  refute_output "FOO: cci"
  refute_output "FOO: "
}

@test "shadowed variable should have priority over the cci-exported one" {
  run cci-export FOO cci
  FOO=bar run "$HOME/test/foo-printer.sh"
  assert_output "FOO: bar"
  refute_output "FOO: cci"
  refute_output "FOO: "
}

@test "shadowed variable should have priority over both: the exported and the cci-exported one" {
  export FOO=bar-export
  run cci-export FOO cci
  FOO=bar-shadow run "$HOME/test/foo-printer.sh"
  assert_output "FOO: bar-shadow"
  refute_output "FOO: bar-export"
  refute_output "FOO: cci"
  refute_output "FOO: "


  run cci-export FOO cci2
  export FOO=bar-export2
  FOO=bar-shadow2 run "$HOME/test/foo-printer.sh"
  assert_output "FOO: bar-shadow2"
  refute_output "FOO: bar-export2"
  refute_output "FOO: cci2"
  refute_output "FOO: "
}
