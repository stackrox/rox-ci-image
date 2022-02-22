#!/usr/bin/env bash

set -eEuo pipefail

usage() {
  echo >&2 "Usage: $0 <branch_name> <repo_name> <pr_title> <pr_description_body> <pr-labels...>"
  exit 2
}

main() {
  [[ -n "${GITHUB_TOKEN}" ]] || { echo >&2 "No GitHub token found"; exit 2; }
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

  echo "Fetching known labels..."
  readarray -t known_labels < <(get_existing_labels "$repo_name")
  known_labels_str="$(printf "'%s', " "${known_labels[@]}")"
  echo "Got ${#known_labels[@]} known labels: ${known_labels_str#,}"

  status_code="$(create_pr_and_get_http_status "$pr_description_body")"
  echo "Attempting to open a PR resulted in status code: ${status_code}"

  # 201 is returned on PR creation - the reply body contains PR number
  # 422 is returned when PR cannot be opened because:
  # - the PR already exists
  # - the branch does not exist
  [[ "${status_code}" -eq 201 || "${status_code}" -eq 422 ]]

  pr_number="$(get_pr_number "$repo_name" "$branch_name")"
  echo "Fetched PR number: '${pr_number}'"
  [[ -n "${pr_number}" ]] || die "Missing pr_number"

  echo "Assigning PR to: '${CIRCLE_USERNAME}'"
  set_assignee "$repo_name" "$pr_number" "$CIRCLE_USERNAME"
  echo "Attempting to lable PR with: '${labels[*]}'"
  assign_known_label "$pr_number" "${labels[@]}"
}

github_curl() {
  curl --silent --show-error \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token ${GITHUB_TOKEN}" "${@}"
}

# get_existing_labels returns list of existing labels for a given repo
get_existing_labels() {
  local repo_name="$1"
  github_curl "https://api.github.com/repos/stackrox/${repo_name}/labels?per_page=100" | jq -r '.[].name'
}

get_pr_number(){
  local repo_name="$1"
  local branch_name="$2"
  local result
  result="$(github_curl -X GET "https://api.github.com/repos/stackrox/${repo_name}/pulls?head=stackrox:${branch_name}" | jq -r '.[0].number')"
  if [ "$result" != "null" ]; then
    echo "$result";
  else
    >&2 echo "Unable to find PR number for repo:branch '${repo_name}:${branch_name}'"
    return 1;
  fi
}

assign_known_label() {
  local pr_number="$1"
  (( pr_number > 0 )) || die "PR number '$pr_number' is not a number"
  shift;
  local labels=("$@")
  [[ "${#labels}" -gt 0 ]] || return 0
  local labels_to_add=()

  for label in "${labels[@]}"; do
    if printf '%s\0' "${known_labels[@]}" | grep --fixed-strings -q "$label"; then
      labels_to_add+=( "$label" )
    else
      echo "Skipping label '$label' - label unknown to the repo"
    fi
  done

  local quoted_labels
  quoted_labels="$(printf ", \"%s\"" "${labels_to_add[@]}")"
  local payload
  payload="$(printf '{"labels": [%s]}' "${quoted_labels#,}")"

  github_curl \
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
  github_curl \
    -X POST \
    -o /dev/null \
    "https://api.github.com/repos/stackrox/${repo_name}/issues/${pr_number}/assignees" \
    -d "$payload"
}

create_pr_and_get_http_status() {
  local pr_description_body="$1"
  local pr_description="$pr_description_header.
  $pr_description_body"
  local payload
  payload="$(printf '{"title": "%s", "body": %s, "head": "%s", "base": "master"}' "$pr_title" "$(jq -sR <<<"$pr_description")" "$branch_name")"
  github_curl \
    -w '%{http_code}' \
    -o /dev/null \
    -X POST \
    "https://api.github.com/repos/stackrox/${repo_name}/pulls" \
    -d "$payload"
}

die() {
  echo >&2 "$1"
  exit 1
}

main "$@"
