FROM cimg/base:stable

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install all the packages
RUN set -ex \
 && sudo apt-get update \
 && sudo apt-get install --no-install-recommends -y \
      openjdk-8-jdk-headless \
      maven \
 # Upgrade for latest security patches
 && sudo apt upgrade \
 && sudo rm -rf /var/lib/apt/lists/*

# Symlink python to python3
RUN sudo ln -s /usr/bin/python3 /usr/bin/python

# Install gcloud
ARG GCLOUD_VERSION=311.0.0
ARG GCLOUD_SHA256=ec6353b28c5cf2f8737b9604dd45274baccb15fc0aa05157a2a8eb77f4ad37ca
ENV PATH=/home/circleci/google-cloud-sdk/bin:$PATH
RUN set -ex \
 && wget --no-verbose -O /tmp/gcloud.tgz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz \
 && echo "${GCLOUD_SHA256} */tmp/gcloud.tgz" | sha256sum -c - \
 && mkdir -p /home/circleci/google-cloud-sdk \
 && tar -xz -C /home/circleci -f /tmp/gcloud.tgz \
 && /home/circleci/google-cloud-sdk/install.sh \
 && rm -rf /tmp/gcloud.tgz \
 && command -v gcloud \
 && gcloud components install beta

# Install kubectl
ARG KUBECTL_VERSION=v1.19.0
ARG KUBECTL_SHA256=79bb0d2f05487ff533999a639c075043c70a0a1ba25c1629eb1eef6ebe3ba70f
RUN set -ex \
 && wget --no-verbose -O kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
 && echo "${KUBECTL_SHA256} ./kubectl" | sha256sum -c - \
 && sudo install ./kubectl /usr/local/bin \
 && rm kubectl \
 && mkdir -p /home/circleci/.kube \
 && touch /home/circleci/.kube/config \
 && command -v kubectl

COPY ./static-contents/bin/bash-wrapper /bin/

RUN \
  sudo mv /bin/bash /bin/real-bash && \
  sudo mv /bin/bash-wrapper /bin/bash && \
  sudo chmod 755 /bin/bash

USER circleci
