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
      maven \
      unzip \
      openssh-client \
      sudo \
      wget \
      zip \
 && rm -rf /var/lib/apt/lists/*

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

COPY ./static-contents/ /

USER circleci