#!/usr/bin/env bats

# To run the test locally do:
# make stackrox-build-image
# make stackrox-test-image
# make test-cci-export

bats_helpers_root="/usr/lib/node_modules"
load "${bats_helpers_root}/bats-support/load.bash"
load "${bats_helpers_root}/bats-assert/load.bash"

foo_printer() {
  "bats/foo-printer.sh" "${@}"
}

setup() {
  export _CERT="bats/test-ca.crt"
  export _FILE="bats/FILE"
  # Create a file used in test-cases using subshell execution of 'cat'
  echo "1.2.3" > "${_FILE}"
  run test -f "${_FILE}"
  assert_success

  bash_env="$(mktemp)"
  export BASH_ENV="$bash_env"
  # ensure clean start of every test case
  unset FOO
  echo "" > "$bash_env"
  run echo $BASH_ENV
  assert_output "$bash_env"
  run cat $BASH_ENV
  assert_output ""
  run foo_printer
  assert_output "FOO: "
  run test -n $CIRCLECI
  assert_success
  run echo $CIRCLECI
  assert_output "true"
}

@test "cci-export BASH_ENV does not exist" {
  run rm -f "${BASH_ENV}"
  run test -f "${BASH_ENV}"
  assert_failure

  run cci-export FOO cci1
  assert_success
  run foo_printer
  assert_output "FOO: cci1"
  refute_output "FOO: "
}

@test "cci-export sanity check single value" {
  run cci-export FOO cci1
  assert_success
  run foo_printer
  assert_output "FOO: cci1"
  refute_output "FOO: "

  run cci-export FOO cci2
  assert_success
  run foo_printer
  assert_output "FOO: cci2"
  refute_output "FOO: cci1"
}

@test "cci-export should escape special characters in values" {
  run cci-export FOO 'quay.io/stackrox-"io"/super $canner:2.21.0-15-{{g44}(8f)2dc8fa}'
  assert_success
  run foo_printer
  assert_output 'FOO: quay.io/stackrox-"io"/super $canner:2.21.0-15-{{g44}(8f)2dc8fa}'
  refute_output "FOO: "
}

@test "cci-export should properly handle multiline values" {
  # Sanity check on cert test fixture
  run test -f "${_CERT}"
  assert_success
  # The unprocessed cert should be parsable with openssl
  run openssl x509 -in "${_CERT}" -noout
  assert_success

  run cci-export CERT "$(cat ${_CERT})"
  assert_success

  post_cert="${_CERT}.post"
  foo_printer CERT --silent > "$post_cert"
  # openssl should be able to load the cert after processing it with cci-export
  run openssl x509 -in "$post_cert" -noout
  assert_success

  run diff -q "${_CERT}" "$post_cert"
  assert_success
}

@test "cci-export should allow overwriting multiline values" {
  run cci-export CERT "$(cat ${_CERT})"
  assert_success
  run foo_printer "CERT"
  assert_line "CERT: -----BEGIN CERTIFICATE-----"
  assert_line "-----END CERTIFICATE-----"

  run cci-export CERT "dummy"
  run foo_printer "CERT"
  assert_output "CERT: dummy"
}

@test "cci-export should not leave duplicate lines in BASH_ENV" {
  run cci-export FOO foo # creates 2 lines in BASH_ENV
  run cci-export FOO foo2 # removes 2 and creates 2 lines in BASH_ENV

  run bash -c "grep FOO "$BASH_ENV" | wc -l"
  assert_output 2
}

@test "cci-export sanity check many values" {
  run cat "${_FILE}"
  assert_output "1.2.3"

  export VAR=placeholder
  run cci-export VAR1 "text/$VAR/text:$(cat "${_FILE}")"
  run cci-export VAR2 "text/$VAR/text:$(cat "${_FILE}")"
  run cci-export IMAGE3 "text/$VAR/text:$(cat "${_FILE}")"

  run foo_printer "VAR1"
  assert_output "VAR1: text/$VAR/text:$(cat "${_FILE}")"
  assert_output "VAR1: text/placeholder/text:1.2.3"

  run foo_printer VAR2
  assert_output "VAR2: text/$VAR/text:$(cat "${_FILE}")"
  assert_output "VAR2: text/placeholder/text:1.2.3"

  run foo_printer IMAGE3
  assert_output "IMAGE3: text/$VAR/text:$(cat "${_FILE}")"
  assert_output "IMAGE3: text/placeholder/text:1.2.3"
}

@test "cci-export potentially colliding variable names" {
  run cci-export PART1 "value1"
  run cci-export PART1_PART2 "value_joined"
  run cci-export PART1 "value2"

  run foo_printer PART1
  assert_output "PART1: value2"
  refute_output "PART1: value1"
  run foo_printer PART1_PART2
  assert_output "PART1_PART2: value_joined"
}

@test "exported variable should be respected in a script" {
  export FOO=bar
  run foo_printer
  assert_output "FOO: bar"
  refute_output "FOO: "
}

@test "shadowed variable should be respected in a script" {
  FOO=bar run foo_printer
  assert_output "FOO: bar"
  refute_output "FOO: "
}

@test "exported variable should have priority over the cci-exported one" {
  run cci-export FOO cci
  export FOO=bar
  run foo_printer
  assert_output "FOO: bar"
  refute_output "FOO: cci"
  refute_output "FOO: "
}

@test "shadowed variable should have priority over the cci-exported one" {
  run cci-export FOO cci
  FOO=bar run foo_printer
  assert_output "FOO: bar"
  refute_output "FOO: cci"
  refute_output "FOO: "
}

@test "shadowed variable should have priority over both: the exported and the cci-exported one" {
  export FOO=bar-export
  run cci-export FOO cci
  FOO=bar-shadow run foo_printer
  assert_output "FOO: bar-shadow"
  refute_output "FOO: bar-export"
  refute_output "FOO: cci"
  refute_output "FOO: "


  run cci-export FOO cci2
  export FOO=bar-export2
  FOO=bar-shadow2 run foo_printer
  assert_output "FOO: bar-shadow2"
  refute_output "FOO: bar-export2"
  refute_output "FOO: cci2"
  refute_output "FOO: "
}

@test "shadowed empty variable should be respected in a script" {
  run cci-export FOO "value"
  FOO="" run foo_printer
  assert_output "FOO: "
  refute_output "FOO: value"
}
