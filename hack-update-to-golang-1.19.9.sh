#!/bin/bash

# Update go version for existing release CI images without changing anything
# else.

GOLANG_VERSION=1.19.9

from=0.3.50
echo "change to 0.3.50.next"
exit 1
# to=0.3.50.2
repo=quay.io/stackrox-io/apollo-ci
go_url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz"

for image in stackrox-build stackrox-test scanner-build scanner-test; do
    podman pull "${repo}:${image}-${from}"
    podman container rm "${image}-${to}" || true
    podman rmi "${repo}:${image}-${to}"
    podman run -t --name "${image}-${to}" "${repo}:${image}-${from}" sh -c \
        "wget --no-verbose -O go.tgz $go_url && tar -C /usr/local -xzf go.tgz && rm -f go.tgz"
    podman commit "${image}-${to}" "${repo}:${image}-${to}"
    podman container rm "${image}-${to}"
    update="$(podman run --rm -t "${repo}:${image}-${to}" go version)"
    if ! [[ "${update}" =~ go${GOLANG_VERSION}  ]]; then
        echo "The update for ${image} failed: ${update} != go${GOLANG_VERSION}"
        exit 1
    fi
    podman push "${repo}:${image}-${to}"
done
