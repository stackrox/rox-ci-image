#!/bin/bash
# vim: set shiftwidth=4 expandtab :
set -eu

git_clone_and_branch() {
    # Git clone
    git clone "git@github.com:stackrox/$REPO.git" "$REPO_SOURCE_ROOT"
    pushd "$REPO_SOURCE_ROOT"

    # Git config
    git config user.email "roxbot@stackrox.com"
    git config user.name "RoxBot"

    # Git switch branch (create as needed) and add first commit on which to base PR
    if git fetch --quiet origin "$BRANCH_NAME"; then
        git checkout "$BRANCH_NAME"
        git pull --quiet --set-upstream origin "$BRANCH_NAME"
    else
        git checkout -b "$BRANCH_NAME"
        git commit --allow-empty -am "Noop commit [ci skip]"
        git push --set-upstream origin "$BRANCH_NAME"
    fi
}

update_image_refs() {
    local flavor comment tag
    flavor="$1"
    comment="# TODO(do not merge): this image ref should be updated from a new tag after upstream PR is merged"
    tag="$("$ORIG_CWD/scripts/get_tag.sh" "$flavor")"

    pushd "$REPO_SOURCE_ROOT"

    # Open/update a PR and configure labels, assignees
    # This must happen before pushing changes to the branch
    "$ORIG_CWD/scripts/create_update_pr.sh" \
        "$BRANCH_NAME" \
        "$REPO" \
        "Update apollo-ci image" \
        "Bump version of apollo-ci image used in CI" \
        "$LABELS"

    sed -r -i "s@(.*)/apollo-ci:${flavor}-[0-9].*@\1/apollo-ci:${tag} ${comment}@g" .circleci/config.yml

    if [[ ("$flavor" == "stackrox" && "$REPO" == "stackrox") ||
          ("$flavor" == "scanner" && "$REPO" == "scanner") ]]; then
        echo "${tag} ${comment}" > BUILD_IMAGE_VERSION
        git add BUILD_IMAGE_VERSION
    fi

    if [[ ("$flavor" == "stackrox-test" && "$REPO" == "stackrox") ||
          ("$flavor" == "scanner-test" && "$REPO" == "scanner") ]]; then
        sed -r -i "s@(.*)/apollo-ci:${flavor}-[0-9].*@\1/apollo-ci:${tag}@g" .openshift-ci/Dockerfile.build_root
        git add .openshift-ci/Dockerfile.build_root
    fi

    if git diff-files --quiet; then
        echo "There are no changes to commit in the dependent repo"
    else
        echo "---- BEGIN patch ----"
        git diff-files -p
        echo "---- END patch ----"
        # It may happen that the diff is empty and we still land in this if-branch (not sure why),
        # thus adding `--allow-empty` to not fail the commiting in such cases
        git commit --allow-empty -am "Bump apollo-ci:$flavor image tag to ${tag##:}"
        git push origin "$BRANCH_NAME"
    fi
}


# __MAIN__
REPO="${1:-none}"            # string -- name of the repo where the PR should be opened
LABELS="${2:-none}"         # string -- space separated list of PR labels to add
IMAGE_FLAVORS="${3:-none}"  # string - -Comma separated list of apollo-ci flavors to use
BRANCH_NAME="stackrox-update-ci-image-from-$PR_NUMBER"
ORIG_CWD="$PWD"
REPO_SOURCE_ROOT="/tmp/$REPO"

# TODO(sbostick): skipping automatic PR creation for now
echo "---------------------------------------"
echo "REPO          : [$REPO]"
echo "LABELS        : [$LABELS]"
echo "IMAGE_FLAVORS : [$IMAGE_FLAVORS]"
echo "BRANCH_NAME   : [$BRANCH_NAME]"
echo "ORIG_CWD      : [$ORIG_CWD]"
echo "---------------------------------------"
for flavor in ${IMAGE_FLAVORS//,/ /}; do
    echo "SKIPPING update_image_ref for [$flavor]"
done
exit 0

git_clone_and_branch

for flavor in ${IMAGE_FLAVORS//,/ /}; do
    update_image_refs "$flavor"
done
