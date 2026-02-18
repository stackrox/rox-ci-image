# Provides the tooling required to run StackRox dockerized build targets.

FROM registry.access.redhat.com/ubi8:latest

ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN touch /i-am-rox-ci-image

RUN dnf update -y && \
    dnf install -y \
        dnf-plugins-core \
        wget \
        && \
    dnf config-manager --set-enabled ubi-8-codeready-builder-rpms && \
    dnf update -y && \
    wget --quiet -O - https://rpm.nodesource.com/setup_lts.x | bash - && \
    wget --quiet -O - https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo && \
    dnf update -y && \
    # This set replaces centos:stream8 "Development Tools". It is possible
    # rox-ci-image does not need all of these.
    dnf install -y \
        autoconf \
        automake \
        binutils \
        gcc \
        gcc-c++ \
        gdb \
        glibc-devel \
        libtool \
        make \
        pkgconf \
        pkgconf-m4 \
        pkgconf-pkg-config \
        redhat-rpm-config \
        rpm-build \
        strace \
        ctags \
        git \
        perl-Fedora-VSP \
        perl-generators \
        source-highlight && \
    dnf install -y \
        bzip2-devel \
        gettext \
        git-core \
        jq \
        zstd \
        lz4-devel \
        nodejs \
        procps-ng \
        yarn \
        zlib-devel \
        && \
    dnf upgrade -y && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/cache/yum

ARG GOLANG_VERSION=1.25.3
ARG GOLANG_SHA256=0335f314b6e7bfe08c3d0cfaa7c19db961b7b99fb20be62b0a826c992ad14e0f
ARG GOLANG_SHA256_ARM64=1d42ebc84999b5e2069f5e31b67d6fc5d67308adad3e178d5a2ee2c9ff2001f5
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN set -ex && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-arm64.tar.gz"; \
        sha="${GOLANG_SHA256_ARM64}"; \
    else \
        url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz"; \
        sha="${GOLANG_SHA256}"; \
    fi && \
    wget --no-verbose -O go.tgz "$url" && \
    echo "${sha}  go.tgz" | sha256sum -c - && \
    tar -C /usr/local -xzf go.tgz && \
    rm go.tgz && \
    mkdir -p "$GOPATH/src" "$GOPATH/bin" && \
    chmod -R 777 "$GOPATH"

ARG FETCH_VERSION=0.3.5
ARG FETCH_SHA256=8d4d99e903b30dbd24290e9a056a982ea2326a05ded24c63be64df16e7e0d9f0
RUN set -ex && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        wget --no-verbose -O fetch "https://github.com/gruntwork-io/fetch/releases/download/v${FETCH_VERSION}/fetch_linux_amd64" && \
        echo "${FETCH_SHA256} fetch" | sha256sum -c - && \
        install fetch /usr/bin && rm fetch; \
    fi

ARG OSSLS_VERSION=0.11.1
ARG OSSLS_SHA256=f1bf3012961c1d90ba307a46263f29025028d35c209b9a65e5c7d502c470c95f
RUN set -ex && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        wget --no-verbose -O ossls_linux_arm64 "https://github.com/stackrox/ossls/releases/download/v${OSSLS_VERSION}/ossls_linux_arm64" && \
        install ossls_linux_arm64 /usr/bin/ossls && rm -f ossls_linux_arm64; \
    else \
        fetch --repo="https://github.com/stackrox/ossls" --tag="${OSSLS_VERSION}" --release-asset="ossls_linux_amd64" . && \
        echo "${OSSLS_SHA256}  ossls_linux_amd64" | sha256sum -c - && \
        install ossls_linux_amd64 /usr/bin/ossls && rm -f ossls_linux_amd64; \
    fi && \
    ossls version

ENV CGO_ENABLED=1

WORKDIR /go/src/github.com/stackrox/rox
