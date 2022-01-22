FROM ubuntu:20.04

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install all the packages
RUN set -ex \
 && apt-get update \
 && apt-get install --no-install-recommends -y \
      curl \
      ca-certificates \
      git \
      openjdk-8-jdk-headless \
      make \
      maven \
      unzip \
      openssh-client \
      python3 \
      sudo \
      wget \
      zip \
 && rm -rf /var/lib/apt/lists/*

# Upgrade for latest security patches
RUN apt upgrade

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

COPY ./static-contents/bin/bash-wrapper /bin/

RUN \
  mv /bin/bash /bin/real-bash && \
  mv /bin/bash-wrapper /bin/bash && \
  chmod 755 /bin/bash

USER circleci
