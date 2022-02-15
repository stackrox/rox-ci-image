FROM quay.io/centos/centos:stream8
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN dnf -y update && \
    dnf -y install epel-release dnf-plugins-core && \
    dnf config-manager --enable powertools

# Configure rpm repositories required for this image
RUN set -ex \
  && dnf update -y \
  && dnf install -y \
      wget \
  && wget --quiet -O - https://rpm.nodesource.com/setup_lts.x | bash - \
  && wget --quiet -O - https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo

# Upgrade for latest security patches
RUN set -ex \
  && dnf update -y \
  && dnf upgrade -y

RUN set -ex \
  && dnf install -y \
      git \
      git-core \
      sudo \
      nodejs \
      yarn

# Install bats
RUN set -ex \
  && npm install -g bats@1.5.0 bats-support@0.3.0 bats-assert@2.0.0 tap-junit@5.0.1 \
  && bats -v

RUN set -ex \
 && groupadd --gid 3434 circleci \
 && useradd --uid 3434 --gid circleci --shell /bin/bash --create-home circleci \
 && echo 'circleci ALL=NOPASSWD: ALL' > /etc/sudoers.d/50-circleci

# We are copying the contents in static-contents into / in the image, following the directory structure.
# The reason we don't do a simple COPY ./static-contents / is that, in the base image (as of ubuntu:20.04)
# /bin is a symlink to /usr/bin, and so the COPY ends up overwriting the symlink with a directory containing only
# the contents of static-contents/bin, which is NOT what we want.
# The following method of copying to /static-tmp and then explicitly copying file by file works around that.
COPY ./static-contents/ /static-tmp
RUN set -e \
  && find /static-tmp -type f \
    -exec bash -c 'dir="$(dirname "${1}")"; new_dir="${dir#/static-tmp}"; mkdir -p "${new_dir}"; cp "${1}" "${new_dir}";' -- {} \; \
  && rm -r /static-tmp

RUN \
	mv /bin/bash /bin/real-bash && \
	mv /bin/bash-wrapper /bin/bash
