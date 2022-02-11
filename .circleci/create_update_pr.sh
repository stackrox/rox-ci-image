#!/usr/bin/env bash

set -eo pipefail

[[ -n "${GITHUB_TOKEN}" ]] || { echo >&2 "No GitHub token found"; exit 2; }

usage() {
  echo >&2 "Usage: $0 <branch_name> <repo_name> <pr_title> <pr_message> <pr-labels...>"
  exit 2
}

branch_name="$1"
repo_name="$2"
pr_title="$3"
pr_message="$4"
shift; shift; shift; shift;
labels=("${@}")

[[ -n "${CIRCLE_USERNAME}" ]] || die "No CIRCLE_USERNAME found."

[[ -n "$branch_name" ]] || usage
[[ -n "$repo_name" ]] || usage
[[ -n "$pr_title" ]] || usage
[[ -n "$pr_message" ]] || usage

pr_response_file="$(mktemp)"

message="Hello,
This is an automated PR created from ${CIRCLE_PULL_REQUEST:-"'source uknown'"}.
$pr_message"

status_code="$(curl -sS \
  -w '%{http_code}' \
  -o "$pr_response_file" \
  -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/stackrox/${repo_name}/pulls" \
  -d"{
  \"title\": \"$pr_title\",
  \"body\": $(jq -sR <<<"$message"),
  \"head\": \"${branch_name}\",
  \"base\": \"master\"
}")"

echo "Got status code: ${status_code}"
echo "Got PR response: $(cat "${pr_response_file}")"
# 422 is returned if the PR exists already.
[[ "${status_code}" -eq 201 || "${status_code}" -eq 422 ]]
if [[ "${status_code}" -eq 201 ]]; then
  pr_number="$(jq <"$pr_response_file" -r '.number')"
  [[ -n "${pr_number}" ]] || die "Unable to find PR number"

  curl -sS --fail \
    -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/stackrox/${repo_name}/issues/${pr_number}/assignees" \
    -d"{
      \"assignees\": [\"${CIRCLE_USERNAME}\"]
    }"
fi

labels_list="$(printf ",%s" "${labels[@]}")"
echo "Setting PR labels: $labels_list"

if [[ "${#labels[@]}" -gt 0 ]]; then
  curl -sS --fail \
    -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/stackrox/${repo_name}/issues/${pr_number}/labels" \
    -d"{
      \"labels\": [\"$labels_list\"]
    }" || echo "Failed setting labels: ${labels[*]}"
fi
