#!/usr/bin/env bats

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

@test "cci-export sanity check" {
  run cci-export FOO cci1
  assert_success
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: cci1"
  refute_output "FOO: "

  run cci-export FOO cci2
  assert_success
  run cat $BASH_ENV
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: cci2"
  refute_output "FOO: cci1"
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
}
