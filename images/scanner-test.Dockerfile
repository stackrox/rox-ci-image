# Provides the tooling required to build Scanner images and test Scanner
# binaries and images. Builds upon scanner-build.Dockerfile.

ARG BASE_TAG
FROM quay.io/rhacs-eng/apollo-ci:${BASE_TAG} as base

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# We are copying the contents in static-contents into / in the image, following the directory structure.
# The reason we don't do a simple COPY ./static-contents / is that, in the base image (as of ubuntu:20.04)
# /bin is a symlink to /usr/bin, and so the COPY ends up overwriting the symlink with a directory containing only
# the contents of static-contents/bin, which is NOT what we want.
# The following method of copying to /static-tmp and then explicitly copying file by file works around that.
COPY ./static-contents/ /static-tmp
RUN set -ex \
  && find /static-tmp -type f -print0 | \
    xargs -0 -I '{}' -n1 bash -c 'dir="$(dirname "${1}")"; new_dir="${dir#/static-tmp}"; mkdir -p "${new_dir}"; cp "${1}" "${new_dir}";' -- {} \
  && rm -r /static-tmp
# Circle CI uses BASH_ENV to pass an environment for bash. Other environments need
# an initial BASH_ENV as a foundation for cci-export().
ENV BASH_ENV /etc/initial-bash.env

RUN dnf update -y && \
    dnf install -y \
        expect \
        gcc \
        gcc-c++ \
        google-cloud-sdk \
        google-cloud-sdk-gke-gcloud-auth-plugin \
        jq \
        kubectl \
        lsof \
        lz4 \
        openssl \
        @postgresql:12 \
        python3 \
        unzip \
        xz \
        zip \
        && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/cache/yum

# Use updated auth plugin for GCP
ENV USE_GKE_GCLOUD_AUTH_PLUGIN=True
RUN gke-gcloud-auth-plugin --version

# Install docker binary
ARG DOCKER_VERSION=20.10.6
RUN set -ex \
 && DOCKER_URL="https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" \
 && echo Docker URL: $DOCKER_URL \
 && wget --no-verbose -O /tmp/docker.tgz "${DOCKER_URL}" \
 && ls -lha /tmp/docker.tgz \
 && tar -xz -C /tmp -f /tmp/docker.tgz \
 && install /tmp/docker/docker /usr/local/bin \
 && rm -rf /tmp/docker /tmp/docker.tgz \
 && command -v docker \
 && (docker version --format '{{.Client.Version}}' || true)

# helm
RUN set -ex \
 && wget --no-verbose -O helm.tgz https://get.helm.sh/helm-v3.3.0-linux-amd64.tar.gz \
 && tar -xf helm.tgz \
 && install linux-amd64/helm /usr/local/bin \
 && rm -rf helm.tgz linux-amd64 \
 && command -v helm

# Install yq v4.16.2
RUN set -ex \
  && wget --no-verbose "https://github.com/mikefarah/yq/releases/download/v4.16.2/yq_linux_amd64" \
  && sha256sum --check --status <<< "5c911c4da418ae64af5527b7ee36e77effb85de20c2ce732ed14c7f72743084d  yq_linux_amd64" \
  && mv yq_linux_amd64 /usr/bin/yq \
  && chmod +x /usr/bin/yq

# Install hub-comment
RUN set -ex \
  && wget --quiet https://github.com/joshdk/hub-comment/releases/download/0.1.0-rc6/hub-comment_linux_amd64 \
  && sha256sum --check --status <<< "2a2640f44737873dfe30da0d5b8453419d48a494f277a70fd9108e4204fc4a53  hub-comment_linux_amd64" \
  && mv hub-comment_linux_amd64 /usr/bin/hub-comment \
  && chmod +x /usr/bin/hub-comment

RUN \
	mv /bin/bash /bin/real-bash && \
	mv /bin/bash-wrapper /bin/bash