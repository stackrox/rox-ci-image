ARG ROCKSDB_TAG
FROM quay.io/rhacs-eng/apollo-ci:${ROCKSDB_TAG} as builder

FROM quay.io/centos/centos:stream8

RUN yum update -y && \
    yum install -y epel-release dnf-plugins-core && \
    yum config-manager --set-enabled powertools && \
    yum -y groupinstall "Development Tools" && \
    yum install -y \
        bzip2-devel \
        libzstd-devel \
        lz4-devel \
        snappy-devel \
        wget \
        zlib-devel \
        && \
    yum clean all && \
    rm -rf /var/cache/yum

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

RUN wget --quiet -O - https://rpm.nodesource.com/setup_lts.x | bash - && \
    wget --quiet -O - https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo && \
    yum update -y && \
    yum install -y nodejs yarn && \
    yum clean all && \
    rm -rf /var/cache/yum

COPY --from=builder /tmp/rocksdb/librocksdb.a /lib/rocksdb/librocksdb.a
COPY --from=builder /tmp/rocksdb/include /lib/rocksdb/include
COPY --from=builder /tmp/rocksdb/ldb /usr/local/bin/ldb

ENV CGO_CFLAGS="-I/lib/rocksdb/include"
ENV CGO_LDFLAGS="-L/lib/rocksdb -lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy -llz4 -lzstd"
ENV CGO_ENABLED=1
ENV GOCACHE="/linux-gocache"

WORKDIR /go/src/github.com/stackrox/rox
