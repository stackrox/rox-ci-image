# Provides the tooling required to run StackRox dockerized build targets.

FROM registry.access.redhat.com/ubi8:latest

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

ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
ARG GOLANG_VERSION=1.24.4
RUN set -e; case "$(uname -m)" in \
        "x86_64" ) GOLANG_ARCH="amd64" GOLANG_SHA256="77e5da33bb72aeaef1ba4418b6fe511bc4d041873cbf82e5aa6318740df98717";; \
        "aarch64") GOLANG_ARCH="arm64" GOLANG_SHA256="d5501ee5aca0f258d5fe9bfaed401958445014495dc115f202d43d5210b45241";; \
        *) echo "Unsupported $(uname -m)"; exit 1;; \
    esac && \
    wget --no-verbose -O go.tgz "https://dl.google.com/go/go${GOLANG_VERSION}.linux-${GOLANG_ARCH}.tar.gz" && \
    echo "${GOLANG_SHA256} *go.tgz" | sha256sum -c - && \
    tar -C /usr/local -xzf go.tgz && \
    rm go.tgz && \
    mkdir -p "$GOPATH/src" "$GOPATH/bin" && \
    chmod -R 777 "$GOPATH"

ARG FETCH_VERSION=0.4.6
RUN set -e; case "$(uname -m)" in \
        "x86_64" ) FETCH_ARCH="amd64" FETCH_SHA256="a67ed3141d6deb7e7841f40505cba11eb7a37abbab78374712a42373e7854209";; \
        "aarch64") FETCH_ARCH="arm64" FETCH_SHA256="4b9115a1f1a90c7088bff9ffc7d2de3547ef1d21709528e878af09a4c348dea3";; \
        *) echo "Unsupported $(uname -m)"; exit 1;; \
    esac && \
    wget --no-verbose -O fetch https://github.com/gruntwork-io/fetch/releases/download/v${FETCH_VERSION}/fetch_linux_${FETCH_ARCH} && \
    echo "${FETCH_SHA256} fetch" | sha256sum -c - && \
    install fetch /usr/bin && \
    rm fetch

ARG OSSLS_VERSION=0.11.1
RUN set -e; case "$(uname -m)" in \
        "x86_64" ) OSSLS_ARCH="amd64" OSSLS_SHA256="f1bf3012961c1d90ba307a46263f29025028d35c209b9a65e5c7d502c470c95f";; \
        *) echo "Unsupported $(uname -m), skipping."; exit 0;; \
    esac && \
    fetch --repo="https://github.com/stackrox/ossls" --tag="${OSSLS_VERSION}" --release-asset="ossls_linux_${OSSLS_ARCH}" . && \
    echo "${OSSLS_SHA256} *ossls_linux_${OSSLS_ARCH}" | sha256sum -c - && \
    install ossls_linux_${OSSLS_ARCH} /usr/bin/ossls && \
    rm ossls_linux_${OSSLS_ARCH} && \
    ossls version

ENV CGO_ENABLED=1

WORKDIR /go/src/github.com/stackrox/rox
