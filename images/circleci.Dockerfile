# Adds functionality specific to Circle CI.

ARG BASE_TAG
FROM quay.io/rhacs-eng/apollo-ci:${BASE_TAG}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV GOCACHE="/linux-gocache"

# Circle CI manages its own BASH_ENV.
ENV BASH_ENV=

RUN set -ex && \
    yum update -y && \
    yum install -y \
        sudo \
        && \
    yum clean all && \
    rm -rf /var/cache/yum && \
    groupadd --gid 3434 circleci && \
    useradd --uid 3434 --gid circleci --shell /bin/bash --create-home circleci && \
    echo 'circleci ALL=NOPASSWD: ALL' > /etc/sudoers.d/50-circleci && \
    chown -R circleci:circleci "$GOPATH" && \
    mkdir -p "$GOCACHE" && \
    chown -R circleci:circleci "$GOCACHE"

USER circleci
