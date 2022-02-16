FROM quay.io/centos/centos:stream8

ENV ROCKSDB_VERSION "v6.7.3"

RUN dnf -y update && \
    dnf -y install epel-release dnf-plugins-core && \
    dnf config-manager --enable powertools

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
        lz4-devel \
        gflags \
        snappy-devel \
        libzstd-devel

WORKDIR /tmp
RUN git clone -b "${ROCKSDB_VERSION}" --depth 1 https://github.com/facebook/rocksdb.git
WORKDIR /tmp/rocksdb
ENV PORTABLE=1 \
  TRY_SSE_ETC=0 \
  TRY_SSE42="-msse4.2" \
  TRY_PCLMUL="-mpclmul" \
  CXXFLAGS="-fPIC"
RUN make static_lib
