# Provides the tooling required to run Scanner dockerized build targets.

FROM quay.io/centos/centos:stream9

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN dnf update -y && \
    dnf install -y dnf-plugins-core wget && \
    dnf -y groupinstall "Development Tools" && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/cache/yum

ARG GOLANG_VERSION=1.20.4
ARG GOLANG_SHA256_x86_64=698ef3243972a51ddb4028e4a1ac63dc6d60821bf18e59a807e051fee0a385bd
ARG GOLANG_SHA256_s390x=57f999a4e605b1dfa4e7e58c7dbae47d370ea240879edba8001ab33c9a963ebf
ARG GOLANG_SHA256_ppc64le=8c6f44b96c2719c90eebabe2dd866f9c39538648f7897a212cac448587e9a408
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN GOLANG_SHA256="GOLANG_SHA256_$(uname -m)" && \
    GOLANG_ARCH="$([ $(uname -m) == "x86_64" ] && echo "amd64" || echo "$(uname -m)")" && \
    url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-${GOLANG_ARCH}.tar.gz" && \
    wget --no-verbose -O go.tgz "$url" && \
    echo "${!GOLANG_SHA256} *go.tgz" | sha256sum -c - && \
    tar -C /usr/local -xzf go.tgz && \
    rm go.tgz && \
    mkdir -p "$GOPATH/src" "$GOPATH/bin" && \
    chmod -R 777 "$GOPATH"

# fetch
ARG FETCH_VERSION=0.4.6
RUN cd /tmp && \
    git clone https://github.com/gruntwork-io/fetch && \
    cd fetch && \
    git checkout v${FETCH_VERSION} && \
    go build && \
    install fetch /usr/bin && \
    rm -Rf /tmp/fetch

# ossls
ARG OSSLS_VERSION=0.10.1
RUN cd /tmp && \
    git clone https://github.com/stackrox/ossls.git && \
    cd ossls && \
    git checkout ${OSSLS_VERSION} && \
    go build && \
    install ossls /usr/bin && \
    rm -Rf /tmp/ossls

WORKDIR /go/src/github.com/stackrox/scanner
