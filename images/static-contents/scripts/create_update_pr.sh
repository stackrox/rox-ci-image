#!/usr/bin/env bash

set -eEuo pipefail

usage() {
  echo >&2 "Usage: $0 <branch_name> <repo_name> <pr_title> <pr_description_body> [pr-labels...]"
  exit 2
}

# This script opens or updates a new PR according to the following requirements:
# 1. The PR should be assigned to a person who triggered the CI flow
# 2. The PR should have labels applied before the CI workflow for new PRs is triggered
#    If the PR does not exist yet, we do the following:
#    - (1) push empty commit (with [ci skip] in the message) to the branch,
#    - (2) apply PR labels, and
#    - (3) push code changes.
#   If the PR already exists, we only execute step (3).
#   This allows us to trigger the first CI run first after the PR-labels are applied.
#   The reason for this implementation is the Github API that does not allow to open a PR and assign a label with a single API call
#   and we want to make sure that the first CI run already takes the labels into consideration
main() {
  [[ -n "${GITHUB_TOKEN}" ]] || die "No GitHub token found"

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

  echo "Fetching known labels..."
  readarray -t known_labels < <(get_repo_labels "$repo_name")
  known_labels_str="$(printf "'%s', " "${known_labels[@]}")"
  echo "Got ${#known_labels[@]} known labels: ${known_labels_str#,}"

  status_code="$(create_pr_and_get_http_status "$repo_name" "$branch_name" "$pr_title" "$pr_description_body")"
  echo "Attempting to open a PR resulted in status code: ${status_code}"

  # 201 is returned on PR creation - the reply body contains PR number
  # 422 is returned when PR cannot be opened because:
  # - the PR already exists
  # - the branch does not exist
  [[ "${status_code}" -eq 201 || "${status_code}" -eq 422 ]]

  pr_number="$(get_pr_number "$repo_name" "$branch_name")"
  echo "Fetched PR number: '${pr_number}'"
  (( pr_number > 0 )) || die "Missing pr_number"

  echo "Assigning PR to: '${CIRCLE_USERNAME}'"
  set_assignee "$repo_name" "$pr_number" "$CIRCLE_USERNAME"

  [[ "${#labels}" -gt 0 ]] || return 0
  local labels_to_add=()
  for label in "${labels[@]}"; do
    if array_contains "$label" "${known_labels[@]}"; then
      labels_to_add+=( "$label" )
    else
      echo "Skipping label '$label'"
    fi
  done
  assign_label "$repo_name" "$branch_name" "$pr_number" "${labels_to_add[@]}"
}

array_contains() {
  local needle="$1"; shift
  local haystack=("${@}")
	printf '%s\0' "${haystack[@]}" | grep --fixed-strings -q "$needle"
}

github_curl() {
  curl --silent --show-error \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token ${GITHUB_TOKEN}" "${@}"
}

# get_repo_labels returns list of existing labels for a given repo
get_repo_labels() {
  local repo_name="$1"
  github_curl --fail "https://api.github.com/repos/stackrox/${repo_name}/labels?per_page=100" | jq -r '.[].name'
}

get_pr_number(){
  local repo_name="$1"
  local branch_name="$2"
  local result
  result="$(github_curl --fail "https://api.github.com/repos/stackrox/${repo_name}/pulls?head=stackrox:${branch_name}" | jq -r '.[0].number')"
  if [ "$result" != "null" ]; then
    echo "$result";
  else
    >&2 echo "Unable to find PR number for repo:branch '${repo_name}:${branch_name}'"
    return 1;
  fi
}

assign_label() {
  local repo_name="$1"
  local branch_name="$2"
  local pr_number="$3"
  shift; shift; shift;
  local labels_to_add=("$@")
  [[ ${#labels_to_add[@]} == 0 ]] && { echo "No new labels to add"; return 0; }
  (( pr_number > 0 )) || die "PR number '$pr_number' is not a number"
  printf "Assigning labels: %s\n" "$(printf "'%s', " "${labels_to_add[@]}")"

  local quoted_labels
  quoted_labels="$(printf ", \"%s\"" "${labels_to_add[@]}")"
  local payload
  payload="$(printf '{"labels": [%s]}' "${quoted_labels#,}")"

  github_curl --fail \
    -X PUT \
    -o /dev/null \
    "https://api.github.com/repos/stackrox/${repo_name}/issues/${pr_number}/labels" \
    -d "$payload"
}

set_assignee() {
  local repo_name="$1"
  local pr_number="$2"
  local username="$3"
  payload="$(printf '{"assignees": ["%s"]}' "$username")"
  github_curl --fail \
    -X POST \
    -o /dev/null \
    "https://api.github.com/repos/stackrox/${repo_name}/issues/${pr_number}/assignees" \
    -d "$payload"
}

create_pr_and_get_http_status() {
  local repo_name="$1"
  local branch_name="$2"
  local pr_title="$3"
  local pr_description_body="$4"
  local pr_description="This is an automated PR created from ${CIRCLE_PULL_REQUEST:-"'source uknown'"}.
  $pr_description_body"
  local payload
  payload="$(printf '{"title": "%s", "body": %s, "head": "%s", "base": "master"}' "$pr_title" "$(jq -sR <<<"$pr_description")" "$branch_name")"
  # warning: no --fail here - we accept code 422 as not-error
  github_curl \
    -X POST \
    -w '%{http_code}' \
    -o /dev/null \
    "https://api.github.com/repos/stackrox/${repo_name}/pulls" \
    -d "$payload"
}

die() {
  echo >&2 "$1"
  exit 1
}

main "$@"