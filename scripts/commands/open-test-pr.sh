#!/bin/bash
set -eu
exit 1

  open-test-pr:
    parameters:
      repo:
        description: Name of the repo where the PR should be opened.
        type: string
      labels:
        description: Space separated list of PR labels to add.
        type: string
        default: ""
      image-flavors:
        description: The flavors of the apollo-ci image that the target repo uses. A comma separated list.
        type: string
    steps:
      - checkout
      - add_ssh_keys:
          fingerprints:
            - "c7:dd:37:f0:33:4b:a1:16:80:d6:56:48:fd:d3:6c:87"
      - run:
          name: Clone << parameters.repo >> repo
          command: |
            git clone git@github.com:stackrox/<< parameters.repo >>.git /tmp/<< parameters.repo >>
      - run:
          name: Create a commit in << parameters.repo >> that updates dependent images if necessary
          command: |
            if ! .circleci/changes_affect.sh << parameters.repo >>; then
              echo "No need to open/update a PR against << parameters.repo >> - current changes are not affecting this repo."
              exit 0;
            fi

            pushd "/tmp/<< parameters.repo >>"

            git config user.email "roxbot@stackrox.com"
            git config user.name "RoxBot"
            branch_name="stackrox-update-ci-image-from-${CIRCLE_PULL_REQUEST##*/}"
            if git fetch --quiet origin "${branch_name}"; then
              git checkout "${branch_name}"
              git pull --quiet --set-upstream origin "${branch_name}"
            else
              git checkout -b "${branch_name}"
              # The first commit is created to allow opening a PR and setting all required labels before we trigger the CI
              git commit --allow-empty -am "Noop commit [ci skip]"
              git push --set-upstream origin "${branch_name}"
            fi

            todo="# TODO(do not merge): After upstream PR is merged, cut a tag and update this"

            IFS=',' read -r -a flavors \<<<"<< parameters.image-flavors >>"
            for flavor in "${flavors[@]}"; do
              echo "Doing image substitutions for $flavor"
              prefix="$flavor-"
              popd
              tag="$(.circleci/get_tag.sh "$flavor")"

              # Open or update a PR and configure labels, assignees - this must happen before pushing code changes to the branch
              .circleci/create_update_pr.sh \
                "${branch_name}" \
                "<< parameters.repo >>" \
                "Update apollo-ci image" \
                "Bump version of apollo-ci image used in CircleCI" \
                "<< parameters.labels >>"

              pushd "/tmp/<< parameters.repo >>"

              sed -r -i "s@(.*)/apollo-ci:${prefix}[0-9].*@\1/apollo-ci:${tag} ${todo}@g" .circleci/config.yml

              # If the image parameter was originally quoted, we need to close the quote
              sed -r -i "s@\"(.*)/apollo-ci:${tag} # TODO@\"\1/apollo-ci:${tag}\" # TODO@g" .circleci/config.yml

              if [[ ("$flavor" == "stackrox-build" && "<< parameters.repo >>" == "stackrox") ||
                    ("$flavor" == "scanner-build" && "<< parameters.repo >>" == "scanner") ]]; then
                echo "${tag} ${todo}" > BUILD_IMAGE_VERSION
                git add BUILD_IMAGE_VERSION
              fi

              if [[ ("$flavor" == "stackrox-test" && "<< parameters.repo >>" == "stackrox") ||
                    ("$flavor" == "scanner-test" && "<< parameters.repo >>" == "scanner") ]]; then
                sed -r -i "s@(.*)/apollo-ci:${prefix}[0-9].*@\1/apollo-ci:${tag}@g" .openshift-ci/Dockerfile.build_root
                git add .openshift-ci/Dockerfile.build_root
              fi

              if git diff-files --quiet; then
                echo "There are no changes to commit in the dependent repo"
              else
                printf "Committing diff:\n%s\n---End of diff" "$(git diff-files -p)"
                # It may happen that the diff is empty and we still land in this if-branch (not sure why),
                # thus adding `--allow-empty` to not fail the commiting in such cases
                git commit --allow-empty -am "Bump apollo-ci:$flavor image tag to ${tag##:}"
                git push origin "${branch_name}"
              fi
            done


