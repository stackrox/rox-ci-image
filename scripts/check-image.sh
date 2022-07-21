#!/bin/bash
# Use roxct to scan an image for vulnerabilities.
set -eu

IMAGE_TAG_PREFIX="$1"  # string -- stackrox | stackrox-test | collector | ...
TAG="$(./scripts/get_tag.sh "$IMAGE_TAG_PREFIX")"

echo "Downloading roxctl"
curl --retry 3 -k -o roxctl \
     -H "Authorization: Bearer $ROX_API_TOKEN" \
     "https://$STACKROX_CENTRAL_HOST:443/api/cli/download/roxctl-linux"
chmod +x ./roxctl

echo "Scan images for policy deviations and vulnerabilities"
./roxctl image check --endpoint "$STACKROX_CENTRAL_HOST:443" \
         --image "quay.io/rhacs-eng/apollo-ci:${TAG}"
