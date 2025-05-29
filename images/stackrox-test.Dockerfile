# Provides the tooling required to build StackRox images and test StackRox
# binaries and images. Builds upon stackrox-build.Dockerfile.
ARG BASE_TAG
FROM docker:28.0.0 AS static-docker-source

FROM quay.io/rhacs-eng/apollo-ci:${BASE_TAG} AS base

ARG TARGETARCH

RUN case "$TARGETARCH" in \
      amd64)  echo "TARGETARCH_ALT=x86_64" ;; \
      arm64)  echo "TARGETARCH_ALT=aarch64" ;; \
      *) echo "Unsupported $TARGETARCH"; exit 1;; \
    esac > /arch.env

COPY --from=static-docker-source /usr/local/bin/docker /usr/local/bin/docker
COPY --from=static-docker-source /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx

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

# Install cloud-sdk repo from https://cloud.google.com/sdk/docs/install#rpm, which
# is not configured by default on arm64
RUN set -ex \
  && . /arch.env \
  && cat <<EOF > /etc/yum.repos.d/google-cloud-sdk.repo
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el8-${TARGETARCH_ALT}
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Install Postgres repo
RUN . /arch.env && dnf --disablerepo="*" install -y "https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-${TARGETARCH_ALT}/pgdg-redhat-repo-latest.noarch.rpm"

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
        python3.12-devel python3.12-setuptools python3.12-pip \
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

## Symlink python to python3
RUN update-alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.12 1
RUN update-alternatives --install /usr/bin/pip-3 pip-3 /usr/bin/pip3.12 1
RUN ln -s /usr/bin/python3.12 /usr/bin/python

# Use updated auth plugin for GCP
ENV USE_GKE_GCLOUD_AUTH_PLUGIN=True
RUN gke-gcloud-auth-plugin --version

# Install bats
RUN set -ex \
  && npm install -g bats@1.10.0 bats-support@0.3.0 bats-assert@2.0.0 tap-junit \
  && bats -v

# Install oc
RUN set -e; \
    case "$TARGETARCH" in \
        "amd64") OC_ARCH="";; \
        "arm64") OC_ARCH="arm64-";; \
        *) echo "Unsupported $TARGETARCH"; exit 1;; \
    esac \
 && wget --no-verbose -O oc.tgz https://github.com/okd-project/okd/releases/download/4.11.0-0.okd-2023-01-14-152430/openshift-client-linux-${OC_ARCH}4.11.0-0.okd-2023-01-14-152430.tar.gz \
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
RUN . /arch.env \
 && wget --no-verbose -O "awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-${TARGETARCH_ALT}-2.7.17.zip" \
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
RUN set -ex; . /arch.env && case "$TARGETARCH" in \
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
