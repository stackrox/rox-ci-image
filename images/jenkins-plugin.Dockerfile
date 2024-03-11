FROM cimg/base:current

# Avoid interaction with apt-get commands.
# This pops up when doing apt-get install lsb-core,
# which asks for user input for timezone data.
ARG DEBIAN_FRONTEND=noninteractive

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install required packages for stackrox/jenkins-plugin build
RUN set -ex \
 && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
 && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - \
 && sudo apt-get update \
 && sudo apt-get install --no-install-recommends -y \
      google-cloud-cli \
      kubectl \
      openjdk-8-jdk-headless \
      maven \
 # Upgrade for latest security patches
 && sudo apt upgrade \
 && sudo rm -rf /var/lib/apt/lists/*

COPY ./static-contents/bin/bash-wrapper /bin/

RUN \
  sudo mv /bin/bash /bin/real-bash && \
  sudo mv /bin/bash-wrapper /bin/bash && \
  sudo chmod 755 /bin/bash

USER circleci
