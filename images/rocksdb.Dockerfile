# We separate rocksdb Dockerfile and build task to save CI time (~15 minutes).
# The rocksdb image is uses in "rox.Dockerfile" but it changes only when ROCKSDB_VERSION is changed,
# so we tag the image as "rocksdb-<ROCKSDB_VERSION>" and built it only
# if "quay.io/rhacs-eng/apollo-ci:rocksdb-<ROCKSDB_VERSION>" does not exist yet.
FROM registry.access.redhat.com/ubi8/ubi

ARG ROCKSDB_VERSION
ENV ROCKSDB_VERSION $ROCKSDB_VERSION
ENV PORTABLE=1 \
  TRY_SSE_ETC=0 \
  TRY_SSE42="-msse4.2" \
  TRY_PCLMUL="-mpclmul" \
  CXXFLAGS="-fPIC"

RUN dnf -y update && \
    dnf -y install \
        wget \
        make \
        git \
        gcc \
        gcc-c++ \
        cmake \
        file \
        zlib-devel \
        bzip2-devel \
        lz4-devel

WORKDIR /tmp

RUN set -ex && \
    git clone https://github.com/gflags/gflags.git && \
    cd gflags && \
    git checkout v2.0 && \
    ./configure && \
    make && \
    make install

RUN set -ex && \
    git clone https://github.com/google/snappy && \
    cd snappy && \
    git submodule update --init && \
    mkdir build && \
    cd build && \
    cmake ../ && \
    make && \
    make install

ARG ZSTD_VERSION=1.5.2
ARG ZSTD_SHA256=7c42d56fac126929a6a85dbc73ff1db2411d04f104fae9bdea51305663a83fd0
RUN set -ex && \
    wget --no-verbose -O zstd.tgz https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz && \
    echo "${ZSTD_SHA256} zstd.tgz" | sha256sum -c - && \
    tar -xzf zstd.tgz && \
    mv zstd-${ZSTD_VERSION} zstd && \
    cd zstd && \
    make install

RUN git clone -b "${ROCKSDB_VERSION}" --depth 1 https://github.com/facebook/rocksdb.git
WORKDIR /tmp/rocksdb
RUN make static_lib
