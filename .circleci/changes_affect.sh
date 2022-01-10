#!/usr/bin/env bash

set -uo pipefail

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
  [[ " $* " =~  images/static-contents ]]
}

affects_collector() {
  [[ " $* " =~  images/collector.Dockerfile  ]]
}

affects_scanner() {
  [[ " $* " =~  images/rox.Dockerfile  ]]
}

affects_stackrox() {
  [[ " $* " =~  images/rox.Dockerfile  ]]
}

main() {
  files="$(all_changed_files)"
  if affects_all "${files}"; then
    return 0
  fi
  case "${1}" in
    rox|stackrox) affects_stackrox "${files}";;
    collector) affects_collector "${files}";;
    scanner) affects_scanner "${files}";;
    *) false;;
  esac
}

# Allow sourcing and running depending on a context
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$*"
fi
