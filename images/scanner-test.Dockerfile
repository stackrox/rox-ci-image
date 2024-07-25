# Provides the tooling required to build Scanner images and test Scanner
# binaries and images. Builds upon scanner-build.Dockerfile.

ARG BASE_TAG
FROM quay.io/rhacs-eng/apollo-ci:${BASE_TAG} as base

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# We are copying the contents in static-contents into / in the image, following
# the directory structure.
#
# The reason we don't do a simple COPY ./static-contents / is that, in the base
# image (as of ubuntu:20.04) /bin is a symlink to /usr/bin, and so the COPY ends
# up overwriting the symlink with a directory containing only the contents of
# static-contents/bin, which is NOT what we want.
#
# The following method of copying to /static-tmp and then explicitly copying
# file by file works around that.
COPY ./static-contents /static-tmp
RUN set -ex \
 && find /static-tmp -type f -print0 \
  | xargs -0 -I '{}' -n1 \
        bash -c 'dir="$(dirname "${1}")"; new_dir="${dir#/static-tmp}"; mkdir -p "${new_dir}"; cp "${1}" "${new_dir}";' -- {} \
 && rm -r /static-tmp

# Circle CI uses BASH_ENV to pass an environment for bash. Other environments need
# an initial BASH_ENV as a foundation for cci-export().
ENV BASH_ENV /etc/initial-bash.env

# PostgreSQL environment.
ENV PG_MAJOR=15
ENV PATH="$PATH:/usr/pgsql-$PG_MAJOR/bin/"

RUN dnf install --disablerepo="*" -y \
        https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm \
 && dnf update -y \
 && dnf install -y \
        expect \
        gcc \
        gcc-c++ \
        google-cloud-cli \
        google-cloud-cli-gke-gcloud-auth-plugin \
        jq \
        kubectl \
        lsof \
        lz4 \
        openssl \
        procps-ng \
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

# Install docker 25.0.3
ARG DOCKER_VERSION=25.0.3
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

# Install oc 4.15.0-0.okd-2024-02-23-163410
RUN set -ex \
 && wget --no-verbose -O oc.tgz https://github.com/okd-project/okd/releases/download/4.15.0-0.okd-2024-02-23-163410/openshift-client-linux-4.15.0-0.okd-2024-02-23-163410.tar.gz \
 && mkdir "oc-dir" \
 && tar -C "oc-dir" -xf oc.tgz \
 && install oc-dir/oc /usr/local/bin \
 && rm -rf "oc-dir" oc.tgz \
 && command -v oc

# Install helm v3.14.2
RUN set -ex \
 && wget --no-verbose -O helm.tgz https://get.helm.sh/helm-v3.14.2-linux-amd64.tar.gz \
 && tar -xf helm.tgz \
 && install linux-amd64/helm /usr/local/bin \
 && rm -rf helm.tgz linux-amd64 \
 && command -v helm

# Install yq v4.42.1
RUN set -ex \
  && wget --no-verbose https://github.com/mikefarah/yq/releases/download/v4.42.1/yq_linux_amd64 \
  && sha256sum --check --status <<< "1a95960dddd426321354d58d2beac457717f7c49a9ec0806749a5a9e400eb45e  yq_linux_amd64" \
  && install yq_linux_amd64 /usr/bin/yq \
  && command -v yq

# Install hub-comment
RUN set -ex \
  && wget --no-verbose https://github.com/joshdk/hub-comment/releases/download/0.1.0-rc6/hub-comment_linux_amd64 \
  && sha256sum --check --status <<< "2a2640f44737873dfe30da0d5b8453419d48a494f277a70fd9108e4204fc4a53  hub-comment_linux_amd64" \
  && install hub-comment_linux_amd64 /usr/bin/hub-comment \
  && command -v hub-comment

RUN \
	mv /bin/bash /bin/real-bash && \
	mv /bin/bash-wrapper /bin/bash
