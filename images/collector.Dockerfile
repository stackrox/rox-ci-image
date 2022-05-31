FROM quay.io/centos/centos:stream8

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

### cci-export support (and google-cloud-sdk repo)
COPY ./static-contents/ /static-tmp
RUN set -ex \
  && find /static-tmp -type f -print0 | \
    xargs -0 -I '{}' -n1 bash -c 'dir="$(dirname "${1}")"; new_dir="${dir#/static-tmp}"; mkdir -p "${new_dir}"; cp "${1}" "${new_dir}";' -- {} \
  && rm -r /static-tmp

RUN yum update -y && \
    yum install -y epel-release dnf-plugins-core && \
    yum config-manager --set-enabled powertools && \
    yum -y groupinstall "Development Tools" && \
    yum install -y \
        clang-tools-extra \
        cmake \
        google-cloud-sdk \
        jq \
        python38 \
        wget \
        && \
    yum upgrade -y && \
    yum clean all && \
    rm -rf /var/cache/yum

# Symlink python to python3
RUN ln -s /usr/bin/python3 /usr/bin/python

ARG GOLANG_VERSION=1.16.15
ARG GOLANG_SHA256=77c782a633186d78c384f972fb113a43c24be0234c42fef22c2d8c4c4c8e7475
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz" && \
    wget --no-verbose -O go.tgz "$url" && \
    echo "${GOLANG_SHA256} *go.tgz" | sha256sum -c - && \
    tar -C /usr/local -xzf go.tgz && \
    rm go.tgz && \
    mkdir -p "$GOPATH/src" "$GOPATH/bin" && \
    chmod -R 777 "$GOPATH"

RUN \
# Install additional formatters/linters
    go install mvdan.cc/sh/v3/cmd/shfmt@v3.4.1 && \
    wget -qO- "https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.linux.x86_64.tar.xz" | tar -xJv && \
    cp "shellcheck-stable/shellcheck" /usr/bin/ && \
# Install hub-comment
    wget --quiet https://github.com/joshdk/hub-comment/releases/download/0.1.0-rc6/hub-comment_linux_amd64 && \
    install hub-comment_linux_amd64 /usr/bin/hub-comment

### Circle CI support

ENV GOCACHE="/linux-gocache"

RUN set -ex && \
    yum update -y && \
    yum install -y \
        sudo \
        && \
    yum clean all && \
    rm -rf /var/cache/yum && \
    groupadd --gid 3434 circleci && \
    useradd --uid 3434 --gid circleci --shell /bin/bash --create-home circleci && \
    echo 'circleci ALL=NOPASSWD: ALL' > /etc/sudoers.d/50-circleci && \
    chown -R circleci:circleci "$GOPATH" && \
    mkdir -p "$GOCACHE" && \
    chown -R circleci:circleci "$GOCACHE"

ENV ROX_CI_IMAGE=collector-ci-image

RUN \
	mv /bin/bash /bin/real-bash && \
	mv /bin/bash-wrapper /bin/bash

USER circleci

