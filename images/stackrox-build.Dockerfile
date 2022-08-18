# Provides the tooling required to run StackRox dockerized build targets.

ARG STACKROX_CENTOS_TAG
ARG ROCKSDB_TAG
FROM quay.io/rhacs-eng/apollo-ci:${ROCKSDB_TAG} as builder

FROM quay.io/centos/centos:${STACKROX_CENTOS_TAG} as base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN dnf update -y && \
    dnf install -y \
        dnf-plugins-core \
        epel-release \
        wget \
        && \
    dnf config-manager --set-enabled powertools && \
    dnf update -y && \
    wget --quiet -O - https://rpm.nodesource.com/setup_lts.x | bash - && \
    wget --quiet -O - https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo && \
    dnf update -y && \
    dnf -y groupinstall "Development Tools" && \
    dnf install -y \
        bzip2-devel \
        git-core \
        jq \
        libzstd-devel \
        lz4-devel \
        nodejs \
        procps-ng \
        snappy-devel \
        yarn \
        zlib-devel \
        gperftools-libs && \
    dnf upgrade -y && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/cache/yum

ARG GOLANG_VERSION=1.17.2
ARG GOLANG_SHA256=f242a9db6a0ad1846de7b6d94d507915d14062660616a61ef7c808a76e4f1676
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz" && \
    wget --no-verbose -O go.tgz "$url" && \
    echo "${GOLANG_SHA256} *go.tgz" | sha256sum -c - && \
    tar -C /usr/local -xzf go.tgz && \
    rm go.tgz && \
    mkdir -p "$GOPATH/src" "$GOPATH/bin" && \
    chmod -R 777 "$GOPATH"

ARG FETCH_VERSION=0.3.5
ARG FETCH_SHA256=8d4d99e903b30dbd24290e9a056a982ea2326a05ded24c63be64df16e7e0d9f0
RUN wget --no-verbose -O fetch https://github.com/gruntwork-io/fetch/releases/download/v${FETCH_VERSION}/fetch_linux_amd64 && \
    echo "${FETCH_SHA256} fetch" | sha256sum -c - && \
    install fetch /usr/bin && \
    rm fetch

ARG OSSLS_VERSION=0.10.1
ARG OSSLS_SHA256=afdec2fa63b27ced4aeb3297399d45b0f06861e6ebc8cb2431b9653b7f113320
RUN fetch --repo="https://github.com/stackrox/ossls" --tag="${OSSLS_VERSION}" --release-asset="ossls_linux_amd64" . && \
    echo "${OSSLS_SHA256} *ossls_linux_amd64" | sha256sum -c - && \
    install ossls_linux_amd64 /usr/bin/ossls && \
    rm ossls_linux_amd64 && \
    ossls version

COPY --from=builder /tmp/rocksdb/librocksdb.a /lib/rocksdb/librocksdb.a
COPY --from=builder /tmp/rocksdb/include /lib/rocksdb/include
COPY --from=builder /tmp/rocksdb/ldb /usr/local/bin/ldb

ENV CGO_CFLAGS="-I/lib/rocksdb/include"
ENV CGO_LDFLAGS="-L/lib/rocksdb -lrocksdb -ltcmalloc -lprofiler -lstdc++ -lm -lz -lbz2 -lsnappy -llz4 -lzstd"
ENV CGO_ENABLED=1

WORKDIR /go/src/github.com/stackrox/rox
