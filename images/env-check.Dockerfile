FROM ubuntu:20.04

# Avoid interaction with apt-get commands.
# This pops up when doing apt-get install lsb-core,
# which asks for user input for timezone data.
ARG DEBIAN_FRONTEND=noninteractive

# This line makes sure that piped commands in RUN instructions exit early.
# This should not affect use in CircleCI because Circle doesn't use
# CMD/ENTRYPOINT.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Configure all necessary apt repositories
RUN set -ex \
 && apt-get update \
 && apt-get install --no-install-recommends -y \
      apt-transport-https \
      ca-certificates \
      gnupg2 \
      wget \
 && wget --no-verbose -O - https://deb.nodesource.com/setup_lts.x | bash - \
 && wget --no-verbose -O - https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
 && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
 && apt-get remove -y \
      apt-transport-https \
      gnupg2 \
      wget \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

# Install all the packages
RUN set -ex \
 && apt-get update \
 && apt-get install --no-install-recommends -y \
      nodejs \
      yarn=1.19.2-1 \
 && rm -rf /var/lib/apt/lists/*

# Install bats
RUN set -ex \
  && npm install -g bats@1.2.0 tap-junit \
  && bats -v

# Install Circle CI tools
COPY circleci-tools /opt/circleci-tools
ENV PATH=/opt/circleci-tools:$PATH
RUN set -ex \
  && cd /opt/circleci-tools \
  && npm install \
  && command -v pull-workflow-output.js \
  && command -v check-for-sensitive-env-values.js