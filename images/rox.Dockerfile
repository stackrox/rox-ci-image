ARG BASE_TAG
ARG ROCKSDB_TAG="rocksdb-v6.7.3-1"

FROM quay.io/rhacs-eng/apollo-ci:${ROCKSDB_TAG} as rocksdb
FROM quay.io/rhacs-eng/apollo-ci:${BASE_TAG} as base

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install all the packages
# hadolint ignore=DL3008 # require latest versions for security fixes
RUN set -ex \
 && dnf update -y \
 && dnf install -y \
      lsof \
      java-1.8.0-openjdk-headless \
      make \
      cmake \
      gcc \
      gcc-c++ \
      unzip \
      zip \
      xz \
      postgresql \
      # `# Cypress dependencies: (see https://docs.cypress.io/guides/guides/continuous-integration.html#Dependencies)` \
      xorg-x11-server-Xvfb gtk2-devel gtk3-devel libnotify-devel GConf2 nss libXScrnSaver alsa-lib

# Install jq
RUN wget --no-verbose -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
  && chmod +x ./jq \
  && mv ./jq /usr/bin \
  && command -v jq

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

# Install Go
# https://golang.org/dl/
ARG GOLANG_VERSION=1.17.2
ARG GOLANG_SHA256=f242a9db6a0ad1846de7b6d94d507915d14062660616a61ef7c808a76e4f1676
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
RUN set -ex \
 && url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz" \
 && wget --no-verbose -O go.tgz "$url" \
 && echo "${GOLANG_SHA256} *go.tgz" | sha256sum -c - \
 && tar -C /usr/local -xzf go.tgz \
 && rm go.tgz \
 && command -v go \
 && mkdir -p "$GOPATH/src" "$GOPATH/bin" \
 && chmod -R 777 "$GOPATH" \
 && chown -R circleci "$GOPATH"

 # Symlink python to python3
 RUN ln -s /usr/bin/python3 /usr/bin/python

# Install gcloud
# gcloud prefers to run out of a user's home directory.
ARG GCLOUD_VERSION=311.0.0
ARG GCLOUD_SHA256=ec6353b28c5cf2f8737b9604dd45274baccb15fc0aa05157a2a8eb77f4ad37ca
ENV PATH=/home/circleci/google-cloud-sdk/bin:$PATH
RUN set -ex \
 && wget --no-verbose -O /tmp/gcloud.tgz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz \
 && echo "${GCLOUD_SHA256} */tmp/gcloud.tgz" | sha256sum -c - \
 && mkdir -p /home/circleci/google-cloud-sdk \
 && tar -xz -C /home/circleci -f /tmp/gcloud.tgz \
 && /home/circleci/google-cloud-sdk/install.sh \
 && chown -R circleci /home/circleci/google-cloud-sdk \
 && rm -rf /tmp/gcloud.tgz \
 && command -v gcloud \
 && gcloud components install beta

# kubectl
RUN set -ex \
 && wget --no-verbose -O kubectl "https://storage.googleapis.com/kubernetes-release/release/v1.19.0/bin/linux/amd64/kubectl" \
 && install ./kubectl /usr/local/bin \
 && rm kubectl \
 && mkdir -p /home/circleci/.kube \
 && touch /home/circleci/.kube/config \
 && chown -R circleci /home/circleci/.kube/ \
 && command -v kubectl

# oc
RUN set -ex \
 && wget --no-verbose -O oc.tgz https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz \
 && tar -xf oc.tgz \
 && install openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/oc /usr/local/bin \
 && rm -rf openshift-* oc.tgz \
 && command -v oc

# helm
RUN set -ex \
 && wget --no-verbose -O helm.tgz https://get.helm.sh/helm-v3.3.0-linux-amd64.tar.gz \
 && tar -xf helm.tgz \
 && install linux-amd64/helm /usr/local/bin \
 && rm -rf helm.tgz linux-amd64 \
 && command -v helm

# Install gradle
ARG GRADLE_VERSION=7.3.3
ENV PATH=$PATH:/opt/gradle/bin
RUN set -ex \
 && wget --no-verbose https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip \
 && mkdir /opt/gradle \
 && unzip -q gradle-${GRADLE_VERSION}-bin.zip \
 && mv gradle-${GRADLE_VERSION}/* /opt/gradle \
 && rm gradle-${GRADLE_VERSION}-bin.zip \
 && command -v gradle

# Install aws cli
RUN set -ex \
 && wget --no-verbose -O "awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.0.30.zip" \
 && unzip awscliv2.zip \
 && ./aws/install \
 && rm awscliv2.zip \
 && aws --version

# Install anchore cli
RUN set -ex \
 && pip3 install anchorecli==0.9.3 \
 && LC_ALL=C.UTF-8 anchore-cli --version

# Install yq v4.16.2
RUN set -ex \
  && wget --no-verbose "https://github.com/mikefarah/yq/releases/download/v4.16.2/yq_linux_amd64" \
  && sha256sum --check --status <<< "5c911c4da418ae64af5527b7ee36e77effb85de20c2ce732ed14c7f72743084d  yq_linux_amd64" \
  && mv yq_linux_amd64 /usr/bin/yq \
  && chmod +x /usr/bin/yq

RUN dnf -y install \
      zlib-devel \
      bzip2-devel \
      lz4-devel \
      snappy-devel \
      libzstd-devel

COPY --from=rocksdb /tmp/rocksdb/librocksdb.a /tmp/rocksdb/librocksdb.a
COPY --from=rocksdb /tmp/rocksdb/include /tmp/rocksdb/include

ENV CGO_CFLAGS="-I/tmp/rocksdb/include"
ENV CGO_LDFLAGS="-L/tmp/rocksdb -lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy -llz4 -lzstd"

USER circleci
