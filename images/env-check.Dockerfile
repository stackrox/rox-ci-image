FROM cimg/node:lts

# Avoid interaction with apt-get commands.
# This pops up when doing apt-get install lsb-core,
# which asks for user input for timezone data.
ARG DEBIAN_FRONTEND=noninteractive

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -ex \
 && sudo apt-get update \
 # Upgrade for latest security patches
 && sudo apt-get upgrade \
 && sudo rm -rf /var/lib/apt/lists/*

# Install bats
RUN set -ex \
  && sudo npm install -g bats \
  && bats -v

# Install Circle CI tools
COPY circleci-tools /opt/circleci-tools
ENV PATH=/opt/circleci-tools:$PATH
RUN set -ex \
  && sudo chown -R circleci /opt/circleci-tools \
  && cd /opt/circleci-tools \
  && npm install \
  && command -v pull-workflow-output.js \
  && command -v check-for-sensitive-env-values.js

USER circleci
