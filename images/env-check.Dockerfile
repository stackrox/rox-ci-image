FROM cimg/node:lts

# Avoid interaction with apt-get commands.
# This pops up when doing apt-get install lsb-core,
# which asks for user input for timezone data.
ARG DEBIAN_FRONTEND=noninteractive

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root
RUN set -ex \
 && apt-get update \
 # Upgrade for latest security patches
 && apt-get upgrade \
 && rm -rf /var/lib/apt/lists/*

# Install Circle CI tools
COPY circleci-tools /opt/circleci-tools
ENV PATH=/opt/circleci-tools:$PATH

RUN chown -R circleci /opt/circleci-tools

WORKDIR /opt/circleci-tools

RUN set -ex \
  && npm install \
  && command -v pull-workflow-output.js \
  && command -v check-for-sensitive-env-values.js

USER circleci
