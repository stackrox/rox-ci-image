FROM ubuntu:20.04 as base
ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Configure necessary apt repositories and temporarily install packages required for this job
RUN set -ex \
  && apt-get update \
  && apt-get install --no-install-recommends -y \
      apt-transport-https \
      ca-certificates \
      gnupg2 \
      wget \
      lsb-core \
  && wget --no-verbose -O - https://deb.nodesource.com/setup_lts.x | bash - \
  && wget --no-verbose -O - https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
  && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list \
  && apt-get remove -y \
      apt-transport-https \
      gnupg2 \
      lsb-core \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/*

RUN set -ex \
  && apt-get update \
  && apt-get install --no-install-recommends -y \
      git \
      sudo \
      `# Note that the nodejs version is determined by which of the scripts from deb.nodesource.com` \
      `# we execute in the previous job. See https://github.com/nodesource/distributions/blob/master/README.md#deb` \
      nodejs \
      yarn=1.19.2-1 \
  && rm -rf /var/lib/apt/lists/*


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