FROM ubuntu:20.04 as rocksdb

ENV ROCKSDB_VERSION="v6.7.3" PORTABLE=1 TRY_SSE_ETC=0 TRY_SSE42="-msse4.2" TRY_PCLMUL="-mpclmul" CXXFLAGS="-fPIC"

RUN apt-get update && apt-get install -y make git g++ gcc libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev
RUN cd /tmp && git clone -b "${ROCKSDB_VERSION}" --depth 1 https://github.com/facebook/rocksdb.git && cd rocksdb && make static_lib

FROM ubuntu:20.04

# Avoid interaction with apt-get commands.
# This pops up when doing apt-get install lsb-core,
# which asks for user input for timezone data.
ARG DEBIAN_FRONTEND=noninteractive

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Configure all necessary apt repositories
RUN set -ex \
 && apt-get update \
 && apt-get install --no-install-recommends -y \
      apt-transport-https \
      ca-certificates \
      gnupg2 \
      wget \
      # Required in scanner
      rpm \
      lsb-core \
 && wget --no-verbose -O - https://deb.nodesource.com/setup_lts.x | bash - \
 && wget --no-verbose -O - https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
 && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
 && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list \
 && apt-get remove -y \
      apt-transport-https \
      gnupg2 \
      lsb-core \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

# Install all the packages
RUN set -ex \
 && apt-get update \
 && apt-get install --no-install-recommends -y \
      build-essential \
      curl \
      git \
      lsof \
      openjdk-8-jdk-headless \
      # Note that the nodejs version is determined by which of the scripts from deb.nodesource.com
      # we execute in the previous job. See https://github.com/nodesource/distributions/blob/master/README.md#deb
      nodejs \
      unzip \
      # used in scanner
      postgresql-client-12 \
      yarn=1.19.2-1 \
      python3-pip \
      python3-setuptools \
      python3-venv \
      `# OpenShift deployment dependencies:` \
      openssh-client \
      `# Cypress dependencies: (see https://docs.cypress.io/guides/guides/continuous-integration.html#Dependencies)` \
      libgtk2.0-0 \
      libgtk-3-0 \
      libgbm-dev \
      libnotify-dev \
      libgconf-2-4 \
      libnss3 \
      libxss1 \
      libasound2 \
      libxtst6 \
      xauth \
      xvfb \
      xxd \
      sudo \
      `# For envsubst:` \
      gettext \
      zip \
      bind9-host \
 && rm -rf /var/lib/apt/lists/*

# Install bats
RUN set -ex \
  && npm install -g bats@1.5.0 bats-support@0.3.0 bats-assert@2.0.0 tap-junit@5.0.1 \
  && bats -v

# Install jq
RUN curl -L --output jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
  && chmod +x ./jq \
  && sudo mv ./jq /usr/bin \
  && command -v jq

# Configure CircleCI user
RUN set -ex \
 && groupadd --gid 3434 circleci \
 && useradd --uid 3434 --gid circleci --shell /bin/bash --create-home circleci \
 && echo 'circleci ALL=NOPASSWD: ALL' > /etc/sudoers.d/50-circleci

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
ARG GRADLE_VERSION=5.4.1
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
 && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.0.30.zip" -o "awscliv2.zip" \
 && unzip awscliv2.zip \
 && sudo ./aws/install \
 && rm awscliv2.zip \
 && aws --version

# Install anchore cli
RUN set -ex \
 && pip3 install anchorecli==0.7.2 \
 && LC_ALL=C.UTF-8 anchore-cli --version

# Install yq v4.16.2
RUN set -ex \
  && wget https://github.com/mikefarah/yq/releases/download/v4.16.2/yq_linux_amd64 \
  && sha256sum --check --status <<< "5c911c4da418ae64af5527b7ee36e77effb85de20c2ce732ed14c7f72743084d  yq_linux_amd64" \
  && mv yq_linux_amd64 /usr/bin/yq \
  && chmod +x /usr/bin/yq

# We are copying the contents in static-contents into / in the image, following the directory structure.
# The reason we don't do a simple COPY ./static-contents / is that, in the base image (as of ubuntu:20.04)
# /bin is a symlink to /usr/bin, and so the COPY ends up overwriting the symlink with a directory containing only
# the contents of static-contents/bin, which is NOT what we want.
# The following method of copying to /static-tmp and then explicitly copying file by file works around that.
COPY ./static-contents/ /static-tmp
RUN set -e \
  && for file in $(find /static-tmp -type f); do \
    dir="$(dirname "${file}")"; new_dir="${dir#/static-tmp}"; mkdir -p "${new_dir}"; cp "${file}" "${new_dir}"; \
  done \
  && rm -r /static-tmp

RUN \
	mv /bin/bash /bin/real-bash && \
	mv /bin/bash-wrapper /bin/bash

COPY --from=rocksdb /tmp/rocksdb/librocksdb.a /tmp/rocksdb/librocksdb.a
COPY --from=rocksdb /tmp/rocksdb/include /tmp/rocksdb/include

RUN apt-get update && apt-get install -y libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev

ENV CGO_CFLAGS="-I/tmp/rocksdb/include"
ENV CGO_LDFLAGS="-L/tmp/rocksdb -lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy -llz4 -lzstd"

USER circleci