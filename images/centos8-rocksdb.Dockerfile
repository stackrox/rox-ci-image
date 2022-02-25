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

# This compiles RocksDB without BMI and AVX2 instructions
ENV PORTABLE=1 TRY_SSE_ETC=0 TRY_SSE42="-msse4.2" TRY_PCLMUL="-mpclmul" CXXFLAGS="-fPIC"

ARG ROCKSDB_VERSION="v6.7.3"
ARG ROCKSDB_HASH="b0eb4d70d41287860da5ff18b750a796b35e56e"
RUN cd /tmp && \
    git clone -b "${ROCKSDB_VERSION}" --depth 1 https://github.com/facebook/rocksdb.git && \
    cd rocksdb && \
    hash=$(git ls-files -s | git hash-object --stdin) && \
    if [ "${hash}" != "${ROCKSDB_HASH}" ]; then echo "ERROR: Rocks DB version skew detected."; exit 1; fi && \
    make static_lib

RUN cd /tmp/rocksdb && \
    DEBUG_LEVEL=0 make ldb

ARG UPX_VERSION=3.96
ARG UPX_SHA256=ac75f5172c1c530d1b5ce7215ca9e94586c07b675a26af3b97f8421b8b8d413d
RUN url="https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-amd64_linux.tar.xz" && \
    wget --no-verbose -O upx.txz "$url" && \
    echo "${UPX_SHA256} *upx.txz" | sha256sum -c - && \
    tar -xJf upx.txz && \
    "upx-${UPX_VERSION}-amd64_linux/upx" -9 /tmp/rocksdb/ldb && \
    rm -rf upx.txz "upx-${UPX_VERSION}-amd64_linux"
