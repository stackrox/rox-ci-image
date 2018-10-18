FROM ubuntu:18.04@sha256:de774a3145f7ca4f0bd144c7d4ffb2931e06634f11529653b23eba85aef8e378

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Configure all necessary apt repositories
RUN set -ex \
 && apt-get update \
 && apt-get install --no-install-recommends -y \
      apt-transport-https=1.6.3ubuntu0.1 \
      ca-certificates=20180409 \
      gnupg2=2.2.4-1ubuntu1.1 \
      wget=1.19.4-1ubuntu2.1 \
 && wget --no-verbose -O - https://deb.nodesource.com/setup_8.x | bash - \
 && wget --no-verbose -O - https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
 && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
 && apt-get remove -y \
      apt-transport-https \
      gnupg2 \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

# Install all the packages
RUN set -ex \
 && apt-get update \
 && apt-get install --no-install-recommends -y \
      build-essential \
      curl \
      git \
      jq \
      openjdk-8-jdk-headless=8u181-b13-0ubuntu0.18.04.1 \
      nodejs=8.12.0-1nodesource1 \
      unzip \
      yarn=1.10.1-1 \
      # gcloud SDK dependencies:
      python2.7-minimal=2.7.15~rc1-1 \
      libpython-stdlib=2.7.15~rc1-1 \
      # OpenShift deployment dependencies:
      openssh-client \
      # Cypress dependencies:
      xvfb \
      libgtk2.0-0 \
      libnotify-dev \
      libgconf-2-4 \
      libnss3 \
      libxss1 \
      libasound2 \
      sudo \
 && rm -rf /var/lib/apt/lists/*

# Configure CircleCI user
RUN set -ex \
 && groupadd --gid 3434 circleci \
 && useradd --uid 3434 --gid circleci --shell /bin/bash --create-home circleci \
 && echo 'circleci ALL=NOPASSWD: ALL' > /etc/sudoers.d/50-circleci

# Install docker binary
ARG DOCKER_VERSION=18.06.1-ce
RUN set -ex \
 && DOCKER_URL="https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" \
 && echo Docker URL: $DOCKER_URL \
 && wget --no-verbose -O /tmp/docker.tgz "${DOCKER_URL}" \
 && ls -lha /tmp/docker.tgz \
 && tar -xz -C /tmp -f /tmp/docker.tgz \
 && install /tmp/docker/docker /usr/local/bin \
 && rm -rf /tmp/docker /tmp/docker.tgz \
 && command -v docker \
 && (docker version --format '{{.Client.Version}}' || true)

# Install Bazel.
# Bazel installation requires: pkg-config zip g++ zlib1g-dev unzip python
ARG BAZEL_VERSION=0.18.0
ARG BAZEL_INSTALLER_SHA256=48ddaa9c9fef73dbe68517f274f09b33c3c8fdf3410638808b609f82b177d397
RUN set -ex \
 && wget --no-verbose -O install.sh https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh \
 && chmod +x install.sh \
 && echo "${BAZEL_INSTALLER_SHA256} install.sh" | sha256sum -c - \
 && ./install.sh --prefix=/usr/local \
 && rm ./install.sh \
 && command -v bazel

# Install Go
# https://github.com/docker-library/golang/blob/ed78459fac108dab72556146b759516cc65ee109/1.11/stretch/Dockerfile
ARG GOLANG_VERSION=1.11.1
ARG GOLANG_SHA256=2871270d8ff0c8c69f161aaae42f9f28739855ff5c5204752a8d92a1c9f63993
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
RUN set -ex \
 && url="https://golang.org/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz" \
 && wget --no-verbose -O go.tgz "$url" \
 && echo "${GOLANG_SHA256} *go.tgz" | sha256sum -c - \
 && tar -C /usr/local -xzf go.tgz \
 && rm go.tgz \
 && command -v go \
 && mkdir -p "$GOPATH/src" "$GOPATH/bin" \
 && chmod -R 777 "$GOPATH" \
 && chown -R circleci "$GOPATH"

# Add necessary Go build tools
RUN set -ex \
 && go get -u golang.org/x/lint/golint \
 && command -v golint \
 && go get -u golang.org/x/tools/cmd/goimports \
 && command -v goimports \
 && go get -u github.com/jstemmer/go-junit-report \
 && command -v go-junit-report \
 && wget --no-verbose -O $GOPATH/bin/dep https://github.com/golang/dep/releases/download/v0.5.0/dep-linux-amd64 \
 && chmod +x $GOPATH/bin/dep \
 && command -v dep \
 && go get github.com/mattn/goveralls \
 && command -v goveralls \
 && rm -rf $GOPATH/src/* $GOPATH/pkg/*

# Install gcloud
# gcloud prefers to run out of a user's home directory.
ARG GCLOUD_VERSION=218.0.0
ENV PATH=/home/circleci/google-cloud-sdk/bin:$PATH
RUN set -ex \
 && wget --no-verbose -O /tmp/gcloud.tgz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz \
 && mkdir -p /home/circleci/google-cloud-sdk \
 && tar -xz -C /home/circleci -f /tmp/gcloud.tgz \
 && /home/circleci/google-cloud-sdk/install.sh \
 && chown -R circleci /home/circleci/google-cloud-sdk \
 && rm -rf /tmp/gcloud.tgz \
 && command -v gcloud

# kubectl
RUN set -ex \
 && wget --no-verbose -O kubectl "https://storage.googleapis.com/kubernetes-release/release/v1.11.2/bin/linux/amd64/kubectl" \
 && install ./kubectl /usr/local/bin \
 && rm kubectl \
 && mkdir -p /home/circleci/.kube \
 && touch /home/circleci/.kube/config \
 && chown -R circleci /home/circleci/.kube/ \
 && command -v kubectl

# oc
RUN set -ex \
 && wget --no-verbose -O oc.tgz https://github.com/openshift/origin/releases/download/v3.10.0/openshift-origin-client-tools-v3.10.0-dd10d17-linux-64bit.tar.gz \
 && tar -xf oc.tgz \
 && install openshift-origin-client-tools-v3.10.0-dd10d17-linux-64bit/oc /usr/local/bin \
 && rm -rf openshift-* oc.tgz \
 && command -v oc

# Install gradle
ARG GRADLE_VERSION=4.8.1
ENV PATH=$PATH:/opt/gradle/bin
RUN set -ex \
 && wget --no-verbose https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip \
 && mkdir /opt/gradle \
 && unzip -q gradle-${GRADLE_VERSION}-bin.zip \
 && mv gradle-${GRADLE_VERSION}/* /opt/gradle \
 && rm gradle-${GRADLE_VERSION}-bin.zip \
 && command -v gradle

USER circleci
