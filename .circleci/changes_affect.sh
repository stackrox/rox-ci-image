#!/usr/bin/env bash

set -uo pipefail

die() {
  >&2 echo "ERROR: $*"
  exit 1
}

all_changed_files() {
  main_branch="$(git remote show origin | sed -n '/HEAD branch/s/.*: //p')"
  [[ -n "${main_branch}" ]] || die "Failed to get main branch"

  if ! diffbasesha="$(git merge-base HEAD "origin/${main_branch}")"; then
    die "Failed to determine diffbasesha"
  fi

  IFS=$'\n' read -d '' -r -a all_changed_files < <(
    {
      git diff "$diffbasesha" --name-status . |
      sed -n -E -e "s@^[AM][[:space:]]+|^R[^[:space:]]*[[:space:]]+[^[:space:]]+[[:space:]]+@@p" ;
    } | sort | uniq -u ) || true

  echo "${all_changed_files[*]}"
}

affects_all() {
  [[ " $* " =~ [[:space:]]images/static-contents/bin/bash-wrapper[[:space:]] ]]
}

affects_collector() {
  [[ " $* " =~ [[:space:]]images/collector.Dockerfile[[:space:]] ]]
}

affects_scanner() {
  [[ " $* " =~ [[:space:]]images/rox.Dockerfile[[:space:]] ]] \
    || [[ " $* " =~ [[:space:]]images/base.Dockerfile[[:space:]] ]] \
    || [[ " $* " =~ [[:space:]]images/rocksdb.Dockerfile[[:space:]] ]]
}

affects_stackrox() {
  [[ " $* " =~ [[:space:]]images/rox.Dockerfile[[:space:]] ]] \
    || [[ " $* " =~ [[:space:]]images/base.Dockerfile[[:space:]] ]] \
    || [[ " $* " =~ [[:space:]]images/rocksdb.Dockerfile[[:space:]] ]] \
    || [[ " $* " =~ [[:space:]]images/centos8-rocksdb.Dockerfile[[:space:]] ]] \
    || [[ " $* " =~ [[:space:]]images/stackrox-build.Dockerfile[[:space:]] ]] \
    || [[ " $* " =~ [[:space:]]images/static-contents/etc/yum.repos.d/google-cloud-sdk.repo[[:space:]] ]]
}

affects_jenkins-plugin() {
  [[ " $* " =~ [[:space:]]images/jenkins-plugin.Dockerfile[[:space:]] ]]
}

main() {
  files="$(all_changed_files)"
  echo "Changed files: >>>${files}<<<"
  if affects_all "${files}"; then
    return 0
  fi
  case "${1}" in
    rox|stackrox) affects_stackrox "${files}";;
    collector) affects_collector "${files}";;
    scanner) affects_scanner "${files}";;
    jenkins-plugin) affects_jenkins-plugin "${files}";;
    *) false;;
  esac
}

# Allow sourcing and running depending on a context
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$*"
fi
