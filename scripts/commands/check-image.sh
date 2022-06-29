#!/bin/bash
set -eu

# __MAIN__
IMAGE_FLAVOR=${1:-none}  # string -- The flavor of apollo-ci image to check
TAG="$(.circleci/get_tag.sh ${IMAGE_FLAVOR})"

echo "Get roxctl"
curl --retry 3 -k -o roxctl \
     -H "Authorization: Bearer $ROX_API_TOKEN" \
     "https://$STACKROX_CENTRAL_HOST:443/api/cli/download/roxctl-linux"
chmod +x ./roxctl

echo "Scan images for policy deviations and vulnerabilities"
./roxctl image check --endpoint "$STACKROX_CENTRAL_HOST:443" \
         --image "quay.io/rhacs-eng/apollo-ci:${TAG}"
