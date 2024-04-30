FROM quay.io/centos/centos:stream8

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

### cci-export support (and google-cloud-sdk repo)
COPY ./static-contents/ /static-tmp
RUN set -ex \
  && find /static-tmp -type f -print0 | \
    xargs -0 -I '{}' -n1 bash -c 'dir="$(dirname "${1}")"; new_dir="${dir#/static-tmp}"; mkdir -p "${new_dir}"; cp "${1}" "${new_dir}";' -- {} \
  && rm -r /static-tmp

RUN dnf update -y && \
    dnf install -y epel-release dnf-plugins-core && \
    dnf config-manager --set-enabled powertools && \
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
    dnf -y groupinstall "Development Tools" && \
    dnf install -y \
        clang-tools-extra \
        cmake \
        google-cloud-cli \
        jq \
        procps-ng \
        python38 \
        wget \
        docker-ce \
        docker-ce-cli \
        docker-ce-rootless-extras \
        docker-scan-plugin \
        && \
    dnf upgrade -y && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/cache/yum

# Symlink python to python3
RUN ln -s /usr/bin/python3 /usr/bin/python

# Install pip
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python3 get-pip.py

ARG GOLANG_VERSION=1.21.9
ARG GOLANG_SHA256=f76194c2dc607e0df4ed2e7b825b5847cb37e34fc70d780e2f6c7e805634a7ea
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

# Extra python dependencies for test-scripts
RUN pip3 -q install --upgrade scipy google-cloud-storage==2.2.1
