#!/usr/bin/env bash

set -euo pipefail

[[ -n "${GITHUB_TOKEN}" ]] || { echo >&2 "No GitHub token found"; exit 2; }

die() {
  echo >&2 "$1"
  exit 1
}

usage() {
  echo >&2 "Usage: $0 <branch_name> <repo_name> <pr_title> <pr_description_body> <pr-labels...>"
  exit 2
}

pr_description_header="This is an automated PR created from ${CIRCLE_PULL_REQUEST:-"'source uknown'"}."

branch_name="$1"
repo_name="$2"
pr_title="$3"
pr_description_body="$4"
shift; shift; shift; shift;
labels=("${@}")

[[ -n "${CIRCLE_USERNAME}" ]] || die "No CIRCLE_USERNAME found."

[[ -n "$branch_name" ]] || usage
[[ -n "$repo_name" ]] || usage
[[ -n "$pr_title" ]] || usage
[[ -n "$pr_description_body" ]] || usage

create_pr_http_status() {
  local pr_response_file="$1"
  local pr_description_body="$2"
  local pr_description="$pr_description_header.
  $pr_description_body"
  local payload
  payload="$(printf '{"title": "%s", "body": %s, "head": "%s", "base": "master"}' "$pr_title" "$(jq -sR <<<"$pr_description")" "$branch_name")"
  curl -sS \
    -w '%{http_code}' \
    -o "$pr_response_file" \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/stackrox/${repo_name}/pulls" \
    -d "$payload"
}

pr_response_file="$(mktemp)"
status_code="$(create_pr_http_status "$pr_response_file" "$pr_description_body")"

echo "Got status code: ${status_code}"
echo "Got PR response: $(cat "${pr_response_file}")"

# 201 is returned on PR creation - the reply body contains PR number
# 422 is returned if the PR already exists - the reply body does not contain PR number
[[ "${status_code}" -eq 201 || "${status_code}" -eq 422 ]]

if [[ "${status_code}" -eq 201 ]]; then
  pr_number="$(jq <"$pr_response_file" -r '.number' )"
  [[ -n "${pr_number}" ]] || die "Missing pr_number"
  payload="$(printf '{"assignees": ["%s"]}' "$CIRCLE_USERNAME")"
  curl -sS --fail \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/stackrox/${repo_name}/issues/${pr_number}/assignees" \
    -d "$payload"

  quoted_labels="$(printf ", \"%s\"" "${labels[@]}")"
  echo "Setting PR labels: ${quoted_labels#,}"
  payload="$(printf '{"labels": [%s]}' "${quoted_labels#,}")"

  echo "Sending curl payload: $payload"
  curl -sS -v --fail \
    -X PUT \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/stackrox/${repo_name}/issues/${pr_number}/labels" \
    -d "$payload"
fi
