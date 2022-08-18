ARG STACKROX_CENTOS_TAG
FROM quay.io/centos/centos:${STACKROX_CENTOS_TAG}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN dnf update -y && \
    dnf install -y epel-release dnf-plugins-core && \
    dnf config-manager --set-enabled powertools && \
    dnf -y groupinstall "Development Tools" && \
    dnf install -y \
        bzip2-devel \
        libzstd-devel \
        lz4-devel \
        snappy-devel \
        wget \
        zlib-devel \
        && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/cache/yum

# This compiles RocksDB without BMI and AVX2 instructions
ENV PORTABLE=1 TRY_SSE_ETC=0 TRY_SSE42="-msse4.2" TRY_PCLMUL="-mpclmul" CXXFLAGS="-fPIC"

ARG ROCKSDB_VERSION="v6.29.4"
RUN mkdir -p /build && \
    cd /tmp && \
    git clone -b "${ROCKSDB_VERSION}" --depth 1 https://github.com/facebook/rocksdb.git && \
    cd rocksdb && \
    git ls-files -s | git hash-object --stdin >/build/ROCKSDB_HASH && \
    make static_lib

RUN cd /tmp/rocksdb && \
    DEBUG_LEVEL=0 make ldb

