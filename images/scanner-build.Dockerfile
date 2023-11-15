# Provides the tooling required to run Scanner dockerized build targets.

FROM quay.io/centos/centos:stream9

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN dnf update -y && \
    dnf install -y dnf-plugins-core wget && \
    dnf -y groupinstall "Development Tools" && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/cache/yum

ARG GOLANG_VERSION=1.20.10
ARG GOLANG_SHA256_x86_64=80d34f1fd74e382d86c2d6102e0e60d4318461a7c2f457ec1efc4042752d4248
ARG GOLANG_SHA256_s390x=fa32588cbdd1e8adfd7e9f1b4ba3f7a8b424f60e90bf2cc4716650374eb459ae
ARG GOLANG_SHA256_ppc64le=ebac6e713810174f9ffd7f48c17c373fbf359d50d8e6233b1dfbbdebd524fd1c
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN GOLANG_SHA256="GOLANG_SHA256_$(uname -m)" && \
    GOLANG_ARCH="$([ $(uname -m) == "x86_64" ] && echo "amd64" || echo "$(uname -m)")" && \
    url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-${GOLANG_ARCH}.tar.gz" && \
    wget --no-verbose -O go.tgz "$url" && \
    echo "${!GOLANG_SHA256} *go.tgz" | sha256sum -c - && \
    tar -C /usr/local -xzf go.tgz && \
    rm go.tgz && \
    mkdir -p "$GOPATH/src" "$GOPATH/bin" && \
    chmod -R 777 "$GOPATH"

# fetch
ARG FETCH_VERSION=0.4.6
RUN cd /tmp && \
    git clone https://github.com/gruntwork-io/fetch && \
    cd fetch && \
    git checkout v${FETCH_VERSION} && \
    go build && \
    install fetch /usr/bin && \
    rm -Rf /tmp/fetch

# ossls
ARG OSSLS_VERSION=0.10.1
RUN cd /tmp && \
    git clone https://github.com/stackrox/ossls.git && \
    cd ossls && \
    git checkout ${OSSLS_VERSION} && \
    go build && \
    install ossls /usr/bin && \
    rm -Rf /tmp/ossls

WORKDIR /go/src/github.com/stackrox/scanner
