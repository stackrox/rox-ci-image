#!/usr/bin/env bats

setup() {
  load "../third-party/bats-assert/load"
  load "../third-party/bats-support/load"

  # Add 'cci-export' location to PATH
  export PATH="$PWD/static/usr/local/bin:$PATH"

  # Globals
  export _CERT="./test/test-ca.crt"
  export _FILE="./test/INPUT"

  # Create backing store for env persistence (using local file)
  export BASH_ENV="/tmp/bash-env.sh"
  :> "$BASH_ENV"

  # Ensure each test case starts with an empty persistent-env store
  run cat $BASH_ENV
  assert_output ""

  # Sanity check handling of unset variable
  unset FOO
  run ./test/env-var-printer.sh FOO
  assert_output "FOO: "
}

@test "cci-export BASH_ENV does not exist" {
  run rm -f "${BASH_ENV}"
  run test -f "${BASH_ENV}"
  assert_failure

  run cci-export FOO cci1
  assert_success

  run ./test/env-var-printer.sh FOO
  assert_output "FOO: cci1"
  refute_output "FOO: "
}

@test "cci-export sanity check single value" {
  run cci-export FOO cci1
  assert_success
  run ./test/env-var-printer.sh FOO
  assert_output "FOO: cci1"
  refute_output "FOO: "

  run cci-export FOO cci2
  assert_success
  run ./test/env-var-printer.sh FOO
  assert_output "FOO: cci2"
  refute_output "FOO: cci1"
}

@test "cci-export should escape special characters in values" {
  run cci-export FOO 'quay.io/rhacs-"eng"/super $canner:2.21.0-15-{{g44}(8f)2dc8fa}'
  assert_success
  run ./test/env-var-printer.sh FOO
  assert_output 'FOO: quay.io/rhacs-"eng"/super $canner:2.21.0-15-{{g44}(8f)2dc8fa}'
  refute_output "FOO: "
}

@test "cci-export should properly handle multiline values" {
  # Sanity check on cert test fixture
  run test -f "$_CERT"
  assert_success
  # The unprocessed cert should be parsable with openssl
  run openssl x509 -in "$_CERT" -noout
  assert_success

  run cci-export CERT "$(cat $_CERT)"
  assert_success

  POST_CERT="/tmp/cci-export-multiline-cert-test.crt"
  ./test/env-var-printer.sh CERT --silent > "$POST_CERT"
  run openssl x509 -in "$POST_CERT" -noout
  assert_success

  run diff -q "$_CERT" "$POST_CERT"
  assert_success
}

@test "cci-export should allow overwriting multiline values" {
  run cci-export CERT "$(cat $_CERT)"
  assert_success
  run ./test/env-var-printer.sh "CERT"
  assert_line "CERT: -----BEGIN CERTIFICATE-----"
  assert_line "-----END CERTIFICATE-----"

  run cci-export CERT "dummy"
  run ./test/env-var-printer.sh "CERT"
  assert_output "CERT: dummy"
}

@test "cci-export should not leave duplicate lines in BASH_ENV" {
  run cci-export FOO first  # persisted as 1 line in BASH_ENV (initial write)
  run cci-export FOO second # persisted as 1 line in BASH_ENV (overwrite)

  run grep -Ec "^export FOO=" "$BASH_ENV"
  assert_output 1
}

@test "cci-export sanity check many values" {
  run cat "${_FILE}"
  assert_output "1.2.3"

  export VAR=placeholder
  run cci-export VAR1 "text/$VAR/text:$(cat "${_FILE}")"
  run cci-export VAR2 "text/$VAR/text:$(cat "${_FILE}")"
  run cci-export IMAGE3 "text/$VAR/text:$(cat "${_FILE}")"

  run ./test/env-var-printer.sh "VAR1"
  assert_output "VAR1: text/$VAR/text:$(cat "${_FILE}")"
  assert_output "VAR1: text/placeholder/text:1.2.3"

  run ./test/env-var-printer.sh VAR2
  assert_output "VAR2: text/$VAR/text:$(cat "${_FILE}")"
  assert_output "VAR2: text/placeholder/text:1.2.3"

  run ./test/env-var-printer.sh IMAGE3
  assert_output "IMAGE3: text/$VAR/text:$(cat "${_FILE}")"
  assert_output "IMAGE3: text/placeholder/text:1.2.3"
}

@test "cci-export potentially colliding variable names" {
  run cci-export PART1 "value1"
  run cci-export PART1_PART2 "value_joined"
  run cci-export PART1 "value2"

  run ./test/env-var-printer.sh PART1
  assert_output "PART1: value2"
  refute_output "PART1: value1"
  run ./test/env-var-printer.sh PART1_PART2
  assert_output "PART1_PART2: value_joined"
}

@test "exported variable should be respected in a script" {
  export FOO=bar
  run ./test/env-var-printer.sh FOO
  assert_output "FOO: bar"
  refute_output "FOO: "
}

@test "shadowed variable should be respected in a script" {
  FOO=bar run ./test/env-var-printer.sh FOO
  assert_output "FOO: bar"
  refute_output "FOO: "
}

@test "exported variable should have priority over the cci-exported one" {
  ### skip

  run cci-export FOO cci
  export FOO=bar

  run echo "$BASH_ENV"
  assert_output "/tmp/bash-env.sh"

  run ./test/env-var-printer.sh FOO
  assert_output "FOO: bar"
  refute_output "FOO: cci"
  refute_output "FOO: "
}

@test "shadowed variable should have priority over the cci-exported one" {
  ### skip

  run cci-export FOO cci
  FOO=bar run ./test/env-var-printer.sh FOO
  assert_output "FOO: bar"
  refute_output "FOO: cci"
  refute_output "FOO: "
}

@test "shadowed variable should have priority over both: the exported and the cci-exported one" {
  ### skip

  export FOO=bar-export
  run cci-export FOO cci
  FOO=bar-shadow run ./test/env-var-printer.sh FOO
  assert_output "FOO: bar-shadow"
  refute_output "FOO: bar-export"
  refute_output "FOO: cci"
  refute_output "FOO: "


  run cci-export FOO cci2
  export FOO=bar-export2
  FOO=bar-shadow2 run ./test/env-var-printer.sh FOO
  assert_output "FOO: bar-shadow2"
  refute_output "FOO: bar-export2"
  refute_output "FOO: cci2"
  refute_output "FOO: "
}

@test "shadowed empty variable should be respected in a script" {
  ### skip

  run cci-export FOO "value"
  FOO="" run ./test/env-var-printer.sh FOO
  assert_output "FOO: "
  refute_output "FOO: value"
}
