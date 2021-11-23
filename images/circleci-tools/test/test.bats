#!/usr/bin/env bats

if [[ -z "$IMAGE" ]]; then
    CMD=("${BATS_TEST_DIRNAME}/../check-for-sensitive-env-values.js")
    TEST_FIXTURES="${BATS_TEST_DIRNAME}"
else
    # Test via an image where these scripts should be executable and in PATH.
    DOCKER="${DOCKER:-docker}"
    CMD=("$DOCKER" "run" "-v" "${BATS_TEST_DIRNAME}/..:/source:z" "-e" "CIRCLECI_TOKEN" "--rm" "$IMAGE" "check-for-sensitive-env-values.js")
    TEST_FIXTURES="/source/test"
fi

@test "needs args" {
    run ${CMD[@]}
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage" ]]
}

@test "no env values exposed" {
    run ${CMD[@]} "-e" "$TEST_FIXTURES/test.env" "-b" "$TEST_FIXTURES/data-no-env-values"
    # [ "$status" -eq 0 ]
    echo $output
    [ "$output" == "" ]
}

@test "env values exposed" {
    run ${CMD[@]} "-e" "$TEST_FIXTURES/test.env" "-b" "$TEST_FIXTURES/data-with-env-values"
    [ "$status" -eq 1 ]
    [ "$output" != "" ]
}

@test "reports the nearest step" {
    run ${CMD[@]} "-e" "$TEST_FIXTURES/test.env" "-b" "$TEST_FIXTURES/data-with-steps"
    [ "$status" -eq 1 ]
    [[ "${lines[1]}" =~ ">>>> STEP: match" ]]
}

@test "multiple matches" {
    run ${CMD[@]} "-e" "$TEST_FIXTURES/multiple-matches.env" "-b" "$TEST_FIXTURES/multiple-matches"
    [ "$status" -eq 1 ]
    [ "${#lines[@]}" -eq 6 ]
    [[ "${lines[1]}" =~ ">>>> STEP: middle" ]]
    [[ "${lines[3]}" =~ ">>>> STEP: beginning" ]]
    [[ "${lines[5]}" =~ ">>>> STEP: end" ]]
}

@test "multiple builds" {
    run ${CMD[@]} "-e" "$TEST_FIXTURES/multiple-matches.env" "-b" "$TEST_FIXTURES/multiple-builds"
    [ "$status" -eq 1 ]
    [ "${#lines[@]}" -eq 6 ]
    [[ "${lines[0]}" =~ "01" ]]
    [[ "${lines[1]}" =~ ">>>> STEP: middle" ]]
    [[ "${lines[2]}" =~ "02" ]]
    [[ "${lines[3]}" =~ ">>>> STEP: beginning" ]]
    [[ "${lines[4]}" =~ "03" ]]
    [[ "${lines[5]}" =~ ">>>> STEP: end" ]]
}

@test "multiple vars" {
    run ${CMD[@]} "-e" "$TEST_FIXTURES/multiple-vars.env" "-b" "$TEST_FIXTURES/multiple-vars"
    [ "$status" -eq 1 ]
    [ "${#lines[@]}" -eq 6 ]
    [[ "${lines[0]}" =~ 'Key "one"' ]]
    [[ "${lines[1]}" =~ ">>>> STEP: middle" ]]
    [[ "${lines[2]}" =~ 'Key "two"' ]]
    [[ "${lines[3]}" =~ ">>>> STEP: beginning" ]]
    [[ "${lines[4]}" =~ 'Key "three"' ]]
    [[ "${lines[5]}" =~ ">>>> STEP: end" ]]
}

@test "destructs nested JSON" {
    run ${CMD[@]} "-e" "$TEST_FIXTURES/nested-json.env" "-b" "$TEST_FIXTURES/multiple-vars"
    [ "$status" -eq 1 ]
    [ "${#lines[@]}" -eq 6 ]
    [[ "${lines[0]}" =~ 'Key "one"' ]]
    [[ "${lines[1]}" =~ ">>>> STEP: middle" ]]
    [[ "${lines[2]}" =~ 'Key "two-a-b"' ]]
    [[ "${lines[3]}" =~ ">>>> STEP: beginning" ]]
    [[ "${lines[4]}" =~ 'Key "three"' ]]
    [[ "${lines[5]}" =~ ">>>> STEP: end" ]]
}

@test "can skip keys" {
    run ${CMD[@]} "-e" "$TEST_FIXTURES/multiple-vars.env" "-b" "$TEST_FIXTURES/multiple-vars" "--skip" "two"
    [ "$status" -eq 1 ]
    [ "${#lines[@]}" -eq 4 ]
    [[ "${lines[0]}" =~ 'Key "one"' ]]
    [[ "${lines[1]}" =~ ">>>> STEP: middle" ]]
    [[ "${lines[2]}" =~ 'Key "three"' ]]
    [[ "${lines[3]}" =~ ">>>> STEP: end" ]]
}

@test "can skip based on regex" {
    run ${CMD[@]} "-e" "$TEST_FIXTURES/multiple-vars.env" "-b" "$TEST_FIXTURES/multiple-vars" "--skip-re" "^t"
    [ "$status" -eq 1 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "${lines[0]}" =~ 'Key "one"' ]]
    [[ "${lines[1]}" =~ ">>>> STEP: middle" ]]
}

@test "can skip based on multiple regex" {
    run ${CMD[@]} "-e" "$TEST_FIXTURES/multiple-vars.env" "-b" "$TEST_FIXTURES/multiple-vars" "--skip-re" "^t" "^o"
    [ "$status" -eq 0 ]
}
