# Provides the tooling required to build StackRox images and test StackRox
# binaries and images. Builds upon stackrox-build.Dockerfile.

ARG BASE_TAG
FROM quay.io/stackrox-io/apollo-ci:${BASE_TAG} as base

ARG TARGETARCH

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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

# Install Postgres repo
RUN set -ex && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        dnf --disablerepo="*" install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-aarch64/pgdg-redhat-repo-latest.noarch.rpm; \
    else \
        dnf --disablerepo="*" install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm; \
    fi

# Install all the packages
RUN dnf update -y \
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
  && dnf remove -y java-1.8.0-openjdk-headless \
  && dnf --disablerepo="*" --enablerepo="pgdg13" install -y postgresql13 postgresql13-server postgresql13-contrib \
  && dnf --disablerepo="*" --enablerepo="pgdg14" install -y postgresql14 postgresql14-server postgresql14-contrib \
  && dnf --disablerepo="*" --enablerepo="pgdg15" install -y postgresql15 postgresql15-server postgresql15-contrib \
  && dnf clean all \
  && rm -rf /var/cache/dnf /var/cache/yum

# Use updated auth plugin for GCP
ENV USE_GKE_GCLOUD_AUTH_PLUGIN=True
RUN gke-gcloud-auth-plugin --version

# Install bats
RUN set -ex \
  && npm install -g bats@1.10.0 bats-support@0.3.0 bats-assert@2.0.0 tap-junit \
  && bats -v

# Install docker binary
ARG DOCKER_VERSION=29.2.1
RUN set -ex \
 && if [ "$TARGETARCH" = "arm64" ]; then DOCKER_ARCH=aarch64; else DOCKER_ARCH=x86_64; fi \
 && DOCKER_URL="https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz" \
 && echo Docker URL: $DOCKER_URL \
 && wget --no-verbose -O /tmp/docker.tgz "${DOCKER_URL}" \
 && tar -xz -C /tmp -f /tmp/docker.tgz \
 && install /tmp/docker/docker /usr/local/bin \
 && rm -rf /tmp/docker /tmp/docker.tgz \
 && command -v docker \
 && (docker version --format '{{.Client.Version}}' || true)

 # Symlink python to python3
 RUN ln -s /usr/bin/python3 /usr/bin/python

# oc
RUN set -ex \
 && wget --no-verbose -O oc.tgz https://github.com/okd-project/okd/releases/download/4.11.0-0.okd-2022-12-02-145640/openshift-client-linux-4.11.0-0.okd-2022-12-02-145640.tar.gz \
 && mkdir "oc-dir" \
 && tar -C "oc-dir" -xf oc.tgz \
 && install oc-dir/oc /usr/local/bin \
 && rm -rf "oc-dir" oc.tgz \
 && command -v oc

# helm
RUN set -ex \
 && if [ "$TARGETARCH" = "arm64" ]; then helm_arch=arm64; else helm_arch=amd64; fi \
 && wget --no-verbose -O helm.tgz "https://get.helm.sh/helm-v3.11.2-linux-${helm_arch}.tar.gz" \
 && tar -xf helm.tgz \
 && install "linux-${helm_arch}/helm" /usr/local/bin \
 && rm -rf helm.tgz "linux-${helm_arch}" \
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
RUN set -ex \
 && if [ "$TARGETARCH" = "arm64" ]; then aws_arch=aarch64; else aws_arch=x86_64; fi \
 && wget --no-verbose -O "awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}-2.7.17.zip" \
 && unzip awscliv2.zip \
 && ./aws/install \
 && rm awscliv2.zip \
 && rm -rf aws \
 && aws --version

# Install yq v4.16.2
ARG YQ_AMD64_SHA256=5c911c4da418ae64af5527b7ee36e77effb85de20c2ce732ed14c7f72743084d
ARG YQ_ARM64_SHA256=eef1f9db6e10fd5fe8c10ef974d38db49f27095cea0759e7de9b2f202ed498ca
RUN set -ex \
  && if [ "$TARGETARCH" = "arm64" ]; then yq_bin=yq_linux_arm64; yq_sha="${YQ_ARM64_SHA256}"; else yq_bin=yq_linux_amd64; yq_sha="${YQ_AMD64_SHA256}"; fi \
  && wget --no-verbose "https://github.com/mikefarah/yq/releases/download/v4.16.2/${yq_bin}" \
  && echo "${yq_sha}  ${yq_bin}" | sha256sum -c - \
  && mv "${yq_bin}" /usr/bin/yq \
  && chmod +x /usr/bin/yq

# Install hub-comment
RUN set -ex \
  && if [ "$TARGETARCH" = "arm64" ]; then \
       go install "github.com/joshdk/hub-comment@v0.1.0-rc6" && mv "$GOPATH/bin/hub-comment" /usr/bin/hub-comment; \
     else \
       wget --quiet -O hub-comment_linux_amd64 https://github.com/joshdk/hub-comment/releases/download/0.1.0-rc6/hub-comment_linux_amd64 \
       && sha256sum --check --status <<< "2a2640f44737873dfe30da0d5b8453419d48a494f277a70fd9108e4204fc4a53  hub-comment_linux_amd64" \
       && mv hub-comment_linux_amd64 /usr/bin/hub-comment && chmod +x /usr/bin/hub-comment; \
     fi

# Install shellcheck
ARG SHELLCHECK_VERSION=0.10.0
ARG SHELLCHECK_SHA256=6c881ab0698e4e6ea235245f22832860544f17ba386442fe7e9d629f8cbedf87
ARG SHELLCHECK_SHA256_ARM64=324a7e89de8fa2aed0d0c28f3dab59cf84c6d74264022c00c22af665ed1a09bb
RUN set -ex \
  && if [ "$TARGETARCH" = "arm64" ]; then arch=aarch64; pkg="shellcheck-v${SHELLCHECK_VERSION}.linux.${arch}.tar.xz"; sha="${SHELLCHECK_SHA256_ARM64}"; else arch=x86_64; pkg="shellcheck-v${SHELLCHECK_VERSION}.linux.${arch}.tar.xz"; sha="${SHELLCHECK_SHA256}"; fi \
  && wget --quiet "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/${pkg}" \
  && echo "${sha}  ${pkg}" | sha256sum -c - \
  && tar -xJf "${pkg}" \
  && cp "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" /usr/bin/shellcheck \
  && rm -f "${pkg}" && rm -rf "shellcheck-v${SHELLCHECK_VERSION}" \
  && shellcheck --version

# Install hashicorp vault
ARG VAULT_VERSION=1.12.1
ARG VAULT_SHA256=839fa81eacd250e0b0298e518751a792cd5d7194650af78cf5da74d7b7b1e5fb
ARG VAULT_SHA256_ARM64=f583cdd21ed1fdc99ec50f5400e79ebc723ed3ce92d2d1d42490cff9143ed693
RUN set -ex \
  && if [ "$TARGETARCH" = "arm64" ]; then vault_arch=arm64; vault_sha="${VAULT_SHA256_ARM64}"; else vault_arch=amd64; vault_sha="${VAULT_SHA256}"; fi \
  && wget --quiet "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${vault_arch}.zip" \
  && echo "${vault_sha}  vault_${VAULT_VERSION}_linux_${vault_arch}.zip" | sha256sum -c - \
  && unzip "vault_${VAULT_VERSION}_linux_${vault_arch}.zip" \
  && strip "vault" \
  && mv "vault" /usr/bin/vault \
  && rm "vault_${VAULT_VERSION}_linux_${vault_arch}.zip" \
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
