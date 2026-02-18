# Provides the tooling required run UI tests against the StackRox images.

FROM quay.io/centos/centos:stream9

ARG TARGETARCH
ARG TARGETARCH_ALT

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN touch /i-am-rox-ci-image

# We are copying the contents in static-contents into / in the image, following the directory structure.
# The reason we don't do a simple COPY ./static-contents / is that, in the base image (as of ubuntu:20.04)
# /bin is a symlink to /usr/bin, and so the COPY ends up overwriting the symlink with a directory containing only
# the contents of static-contents/bin, which is NOT what we want.
# The following method of copying to /static-tmp and then explicitly copying file by file works around that.
COPY ./static-contents/ /static-tmp
RUN set -ex \
  && find /static-tmp -type f -print0 | \
    xargs -0 -I '{}' -n1 bash -c 'dir="$(dirname "${1}")"; new_dir="${dir#/static-tmp}"; mkdir -p "${new_dir}"; cp "${1}" "${new_dir}";' -- {} \
  && rm -r /static-tmp
# Circle CI uses BASH_ENV to pass an environment for bash. Other environments need
# an initial BASH_ENV as a foundation for cci-export().
ENV BASH_ENV /etc/initial-bash.env

# Install cloud-sdk repo from https://cloud.google.com/sdk/docs/install#rpm, which
# is not configured by default on arm64
RUN set -ex \
  && cat <<EOF > /etc/yum.repos.d/google-cloud-sdk.repo
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-${TARGETARCH_ALT}
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Setup and install some prerequities
RUN dnf update -y  \
  && dnf install -y wget \
  && wget --quiet -O - https://rpm.nodesource.com/setup_lts.x | bash - \
  && wget --quiet -O - https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo \
  && dnf --disablerepo=* -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-${TARGETARCH_ALT}/pgdg-redhat-repo-latest.noarch.rpm \
  && dnf -qy module disable postgresql

# Install all the packages
# We need to fix up the PostgreSQL RPM repository GPG key:
# https://yum.postgresql.org/news/pgdg-rpm-repo-gpg-key-update/
RUN dnf update -y \
  # Shared dependencies with build image
  && dnf install -y \
    bzip2-devel \
    gettext \
    git-core \
    jq \
    zstd \
    lz4-devel \
    nodejs \
    procps-ng \
    yarn \
    zlib-devel \
  # Unique dependencies
  && dnf install -y \
    expect \
    gcc \
    gcc-c++ \
    google-cloud-cli \
    google-cloud-cli-gke-gcloud-auth-plugin \
    java-17-openjdk-devel \
    kubectl \
    lsof \
    lz4 \
    openssl \
    python3-devel \
    unzip \
    xmlstarlet \
    xz \
    zip \
    # `# Cypress dependencies: (see https://docs.cypress.io/guides/guides/continuous-integration.html#Dependencies)`
    xorg-x11-server-Xvfb gtk3-devel nss alsa-lib \
    # PostgreSQL 14
    postgresql14 postgresql14-server postgresql14-contrib \
  && dnf remove -y java-1.8.0-openjdk-headless \
  && dnf clean all \
  && rm -rf /var/cache/dnf /var/cache/yum

ARG GOLANG_VERSION=1.25.3
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
RUN set -e; case "$TARGETARCH" in \
        "amd64" ) GOLANG_SHA256="0335f314b6e7bfe08c3d0cfaa7c19db961b7b99fb20be62b0a826c992ad14e0f";; \
        "arm64")  GOLANG_SHA256="1d42ebc84999b5e2069f5e31b67d6fc5d67308adad3e178d5a2ee2c9ff2001f5";; \
        *) echo "Unsupported $TARGETARCH"; exit 1;; \
    esac && \
    wget --no-verbose -O go.tgz "https://dl.google.com/go/go${GOLANG_VERSION}.linux-${TARGETARCH}.tar.gz" && \
    echo "${GOLANG_SHA256} *go.tgz" | sha256sum -c - && \
    tar -C /usr/local -xzf go.tgz && \
    rm go.tgz && \
    mkdir -p "$GOPATH/src" "$GOPATH/bin" && \
    chmod -R 777 "$GOPATH"

ARG FETCH_VERSION=0.4.6
RUN set -e; case "$TARGETARCH" in \
        "amd64" ) FETCH_SHA256="a67ed3141d6deb7e7841f40505cba11eb7a37abbab78374712a42373e7854209";; \
        "arm64")  FETCH_SHA256="4b9115a1f1a90c7088bff9ffc7d2de3547ef1d21709528e878af09a4c348dea3";; \
        *) echo "Unsupported $TARGETARCH"; exit 1;; \
    esac && \
    wget --no-verbose -O fetch https://github.com/gruntwork-io/fetch/releases/download/v${FETCH_VERSION}/fetch_linux_${TARGETARCH} && \
    echo "${FETCH_SHA256} fetch" | sha256sum -c - && \
    install fetch /usr/bin && \
    rm fetch

ARG OSSLS_VERSION=0.11.1
RUN set -e; case "$TARGETARCH" in \
        "amd64" ) OSSLS_SHA256="f1bf3012961c1d90ba307a46263f29025028d35c209b9a65e5c7d502c470c95f";; \
        *) echo "Unsupported $TARGETARCH, skipping."; exit 0;; \
    esac && \
    fetch --repo="https://github.com/stackrox/ossls" --tag="${OSSLS_VERSION}" --release-asset="ossls_linux_amd64" . && \
    echo "${OSSLS_SHA256} *ossls_linux_amd64" | sha256sum -c - && \
    install ossls_linux_amd64 /usr/bin/ossls && \
    rm ossls_linux_amd64 && \
    ossls version

# Use updated auth plugin for GCP
ENV USE_GKE_GCLOUD_AUTH_PLUGIN=True
RUN gke-gcloud-auth-plugin --version

# Update PATH for Postgres14
ENV PATH=$PATH:/usr/pgsql-14/bin

# Install bats
RUN set -ex \
  && npm install -g bats@1.10.0 bats-support@0.3.0 bats-assert@2.0.0 tap-junit \
  && bats -v

# Install docker binary
ARG DOCKER_VERSION=29.2.1
RUN set -ex \
 && DOCKER_URL="https://download.docker.com/linux/static/stable/${TARGETARCH_ALT}/docker-${DOCKER_VERSION}.tgz" \
 && echo Docker URL: $DOCKER_URL \
 && wget --no-verbose -O /tmp/docker.tgz "${DOCKER_URL}" \
 && ls -lha /tmp/docker.tgz \
 && tar -xz -C /tmp -f /tmp/docker.tgz \
 && install /tmp/docker/docker /usr/local/bin \
 && rm -rf /tmp/docker /tmp/docker.tgz \
 && command -v docker \
 && (docker version --format '{{.Client.Version}}' || true)

 # Symlink python to python3
 RUN ln -s /usr/bin/python3 /usr/bin/python

# oc
ARG OC_VERSION=4.11.0-0.okd-2023-01-14-152430
RUN set -e; \
    case "$TARGETARCH" in \
        "amd64") OC_ARCH="";; \
        "arm64") OC_ARCH="arm64-";; \
        *) echo "Unsupported $TARGETARCH"; exit 1;; \
    esac \
 && wget --no-verbose -O oc.tgz https://github.com/okd-project/okd/releases/download/${OC_VERSION}/openshift-client-linux-${OC_ARCH}${OC_VERSION}.tar.gz \
 && mkdir "oc-dir" \
 && tar -C "oc-dir" -xf oc.tgz \
 && install oc-dir/oc /usr/local/bin \
 && rm -rf "oc-dir" oc.tgz \
 && command -v oc

# helm
RUN set -ex \
 && wget --no-verbose -O helm.tgz https://get.helm.sh/helm-v3.11.2-linux-${TARGETARCH}.tar.gz \
 && tar -xf helm.tgz \
 && install linux-${TARGETARCH}/helm /usr/local/bin \
 && rm -rf helm.tgz linux-${TARGETARCH} \
 && command -v helm

# Install gradle
ARG GRADLE_VERSION=7.5.1
ENV PATH=$PATH:/opt/gradle/bin
RUN set -ex \
 && wget --no-verbose https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip \
 && mkdir /opt/gradle \
 && unzip -q gradle-${GRADLE_VERSION}-bin.zip \
 && mv gradle-${GRADLE_VERSION}/* /opt/gradle \
 && rm gradle-${GRADLE_VERSION}-bin.zip \
 && rmdir gradle-${GRADLE_VERSION} \
 && command -v gradle

# Install aws cli
RUN wget --no-verbose -O "awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-${TARGETARCH_ALT}-2.7.17.zip" \
 && unzip awscliv2.zip \
 && ./aws/install \
 && rm awscliv2.zip \
 && rm -rf aws \
 && aws --version

# Install yq v4.16.2
RUN set -ex \
  && wget --no-verbose "https://github.com/mikefarah/yq/releases/download/v4.16.2/yq_linux_${TARGETARCH}" \
  && mv yq_linux_${TARGETARCH} /usr/bin/yq \
  && chmod +x /usr/bin/yq

# Install hub-comment
RUN set -ex; case "$TARGETARCH" in \
        "amd64");; \
        *) echo "Unsupported ${TARGETARCH}, skipping."; exit 0;; \
    esac \
  && wget --quiet https://github.com/joshdk/hub-comment/releases/download/0.1.0-rc6/hub-comment_linux_amd64 \
  && sha256sum --check --status <<< "2a2640f44737873dfe30da0d5b8453419d48a494f277a70fd9108e4204fc4a53  hub-comment_linux_amd64" \
  && mv hub-comment_linux_amd64 /usr/bin/hub-comment \
  && chmod +x /usr/bin/hub-comment

# Install shellcheck
ARG SHELLCHECK_VERSION=0.10.0
RUN set -ex; case "$TARGETARCH" in \
        "amd64") SHELLCHECK_SHA256="6c881ab0698e4e6ea235245f22832860544f17ba386442fe7e9d629f8cbedf87";; \
        "arm64") SHELLCHECK_SHA256="324a7e89de8fa2aed0d0c28f3dab59cf84c6d74264022c00c22af665ed1a09bb";; \
        *) echo "Unsupported $TARGETARCH"; exit 1;; \
  esac \
  && wget --quiet "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.${TARGETARCH_ALT}.tar.xz" \
  && sha256sum --check --status <<< "${SHELLCHECK_SHA256}  shellcheck-v${SHELLCHECK_VERSION}.linux.${TARGETARCH_ALT}.tar.xz" \
  && tar -xJf "shellcheck-v${SHELLCHECK_VERSION}.linux.${TARGETARCH_ALT}.tar.xz" \
  && cp "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" /usr/bin/shellcheck \
  && rm "shellcheck-v${SHELLCHECK_VERSION}.linux.${TARGETARCH_ALT}.tar.xz" \
  && rm -rf "shellcheck-v${SHELLCHECK_VERSION}" \
  && shellcheck --version

# Install hashicorp vault
ARG VAULT_VERSION=1.12.1
RUN set -ex; case "$TARGETARCH" in \
        "amd64") VAULT_SHA256="839fa81eacd250e0b0298e518751a792cd5d7194650af78cf5da74d7b7b1e5fb";; \
        "arm64") VAULT_SHA256="f583cdd21ed1fdc99ec50f5400e79ebc723ed3ce92d2d1d42490cff9143ed693";; \
        *) echo "Unsupported $TARGETARCH"; exit 1;; \
    esac \
  && wget --quiet "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip" \
  && sha256sum --check --status <<< "${VAULT_SHA256}  vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip" \
  && unzip "vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip" \
  && strip "vault" \
  && mv "vault" /usr/bin/vault \
  && rm "vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip" \
  && vault --version

# Add python development tooling. If these versions have to change check for
# dependent repos. e.g. stackrox/stackrox has .openshift-ci/dev-requirements.txt
# for local development style & lint.
ARG PYCODESTYLE_VERSION=2.10.0
ARG PYLINT_VERSION=2.13.9
RUN set -ex \
  && pip3 install pycodestyle=="${PYCODESTYLE_VERSION}" \
                  pylint=="${PYLINT_VERSION}"

RUN \
	mv /bin/bash /bin/real-bash && \
	mv /bin/bash-wrapper /bin/bash
