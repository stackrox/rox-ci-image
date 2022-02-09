# We separate rocksdb Dockerfile and build task to save CI time (~15 minutes).
# The rocksdb image is uses in "rox.Dockerfile" but it changes only when ROCKSDB_VERSION is changed,
# so we tag the image as "rocksdb-<ROCKSDB_VERSION>" and built it only
# if "quay.io/rhacs-eng/apollo-ci:rocksdb-<ROCKSDB_VERSION>" does not exist yet.
FROM ubuntu:20.04

ARG ROCKSDB_VERSION
ENV ROCKSDB_VERSION $ROCKSDB_VERSION
ENV PORTABLE=1 \
  TRY_SSE_ETC=0 \
  TRY_SSE42="-msse4.2" \
  TRY_PCLMUL="-mpclmul" \
  CXXFLAGS="-fPIC"

RUN apt-get update \
  && apt-get install --no-install-recommends -y \
  make \
  git \
  g++ \
  gcc \
  libgflags-dev \
  libsnappy-dev \
  zlib1g-dev \
  libbz2-dev \
  liblz4-dev \
  libzstd-dev \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && update-ca-certificates

WORKDIR /tmp
RUN git clone -b "${ROCKSDB_VERSION}" --depth 1 https://github.com/facebook/rocksdb.git
WORKDIR /tmp/rocksdb
RUN make static_lib
