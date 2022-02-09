ARG BASE_TAG
FROM quay.io/rhacs-eng/apollo-ci:${BASE_TAG} as base

# Install required packages for stackrox/jenkins-plugin build
RUN set -ex \
 && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
 && sudo apt-get update \
 && sudo apt-get install --no-install-recommends -y \
      google-cloud-sdk \
      kubectl \
      openjdk-8-jdk-headless \
      maven \
 # Upgrade for latest security patches
 && sudo rm -rf /var/lib/apt/lists/*

USER circleci
