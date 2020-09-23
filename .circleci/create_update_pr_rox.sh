#!/usr/bin/env bash

set -eo pipefail

[[ -n "${GITHUB_TOKEN}" ]] || { echo >&2 "No GitHub token found"; exit 2; }

usage() {
  echo >&2 "Usage: $0 <branch_name>"
  exit 2
}

branch_name="$1"

[[ -n "$branch_name" ]] || usage

pr_response_file="$(mktemp)"
status_code_file="$(mktemp)"

message="Hello,
This is an automated PR created to bump the base image.
It was created from ${CIRCLE_PULL_REQUEST}."

curl -sS \
  -w '%{http_code}' \
	-o "$pr_response_file" \
	-X POST \
	-H "Authorization: token ${GITHUB_TOKEN}" \
	'https://api.github.com/repos/stackrox/rox/pulls' \
	-d"{
	\"title\": \"Update rox-ci-image\",
	\"body\": $(jq -sR <<<"$message"),
	\"head\": \"${branch_name}\",
	\"base\": \"master\"
}" > "${status_code_file}"

echo "Got status code: $(cat "${status_code_file}")"
echo "Got PR response: $(cat "${pr_response_file}")"
