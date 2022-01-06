FROM ubuntu:20.04 as base
ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Configure all necessary apt repositories
RUN set -ex \
  && apt-get update \
  && apt-get install --no-install-recommends -y \
      apt-transport-https \
      ca-certificates \
      gnupg2 \
      wget \
      git \
      sudo \
      nodejs \
  && wget --no-verbose -O - https://deb.nodesource.com/setup_lts.x | bash - \
  && wget --no-verbose -O - https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
  && apt-get remove -y \
      apt-transport-https \
      gnupg2 \
      wget \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/*

RUN set -ex \
 && apt-get update \
 && apt-get install --no-install-recommends -y \
      nodejs \
 && rm -rf /var/lib/apt/lists/*

RUN set -ex \
  && npm install -g bats@1.5.0 bats-support@0.3.0 bats-assert@2.0.0 \
  && bats -v

RUN set -ex \
 && groupadd --gid 3434 circleci \
 && useradd --uid 3434 --gid circleci --shell /bin/bash --create-home circleci \
 && echo 'circleci ALL=NOPASSWD: ALL' > /etc/sudoers.d/50-circleci

# Function-under-test setup
FROM base as image_under_test

COPY ./static-contents/ /static-tmp
RUN set -e \
  && for file in $(find /static-tmp -type f); do \
    dir="$(dirname "${file}")"; new_dir="${dir#/static-tmp}"; mkdir -p "${new_dir}"; cp "${file}" "${new_dir}"; \
  done \
  && rm -r /static-tmp

RUN \
	mv /bin/bash /bin/real-bash && \
	mv /bin/bash-wrapper /bin/bash

# Test setup
FROM image_under_test as tester

USER circleci
WORKDIR /home/circleci/test
COPY --chown=circleci:circleci test/ .
ENV CIRCLECI=true

CMD ["bats", "--print-output-on-failure", "--verbose-run", "/home/circleci/test/bats/"]
