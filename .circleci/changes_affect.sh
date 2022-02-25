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
  [[ " $* " =~ \simages/static-contents/bin/bash-wrapper\s ]]
}

affects_collector() {
  [[ " $* " =~ \simages/collector.Dockerfile\s ]]
}

affects_scanner() {
  [[ " $* " =~ \simages/rox.Dockerfile\s ]] \
    || [[ " $* " =~ \simages/base.Dockerfile\s ]] \
    || [[ " $* " =~ \simages/rocksdb.Dockerfile\s ]]
}

affects_stackrox() {
  [[ " $* " =~ \simages/rox.Dockerfile\s ]] \
    || [[ " $* " =~ \simages/base.Dockerfile\s ]] \
    || [[ " $* " =~ \simages/rocksdb.Dockerfile\s ]] \
    || [[ " $* " =~ \simages/centos8-rocksdb.Dockerfile\s ]] \
    || [[ " $* " =~ \simages/stackrox-build.Dockerfile\s ]] \
    || [[ " $* " =~ \simages/static-contents/etc/yum.repos.d/google-cloud-sdk.repo\s ]]
}

affects_jenkins-plugin() {
  [[ " $* " =~ \simages/jenkins-plugin.Dockerfile\s ]]
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
