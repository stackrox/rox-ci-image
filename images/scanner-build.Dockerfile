# Provides the tooling required to run Scanner dockerized build targets.

FROM registry.access.redhat.com/ubi8:latest

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN dnf update -y && \
    dnf install -y dnf-plugins-core wget && \
    dnf config-manager --set-enabled ubi-8-codeready-builder-rpms && \
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
    dnf upgrade -y && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/cache/yum

# Install Go v1.22.5
ARG GOLANG_VERSION=1.22.5
ARG GOLANG_SHA256=904b924d435eaea086515bc63235b192ea441bd8c9b198c507e85009e6e4c7f0
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz" && \
    wget --no-verbose -O go.tgz "$url" && \
    echo "${GOLANG_SHA256} *go.tgz" | sha256sum -c - && \
    tar -C /usr/local -xzf go.tgz && \
    rm go.tgz && \
    mkdir -p "$GOPATH/src" "$GOPATH/bin" && \
    chmod -R 777 "$GOPATH"

# Install fetch v0.4.6
ARG FETCH_VERSION=0.4.6
ARG FETCH_SHA256=a67ed3141d6deb7e7841f40505cba11eb7a37abbab78374712a42373e7854209
RUN wget --no-verbose -O fetch https://github.com/gruntwork-io/fetch/releases/download/v${FETCH_VERSION}/fetch_linux_amd64 && \
    echo "${FETCH_SHA256} fetch" | sha256sum -c - && \
    install fetch /usr/bin

# Install ossls 0.11.1
ARG OSSLS_VERSION=0.11.1
ARG OSSLS_SHA256=f1bf3012961c1d90ba307a46263f29025028d35c209b9a65e5c7d502c470c95f
RUN fetch --repo="https://github.com/stackrox/ossls" --tag="${OSSLS_VERSION}" --release-asset="ossls_linux_amd64" . && \
    echo "${OSSLS_SHA256} *ossls_linux_amd64" | sha256sum -c - && \
    install ossls_linux_amd64 /usr/bin/ossls && \
    rm ossls_linux_amd64 && \
    ossls version

WORKDIR /go/src/github.com/stackrox/scanner
