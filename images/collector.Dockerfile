FROM cimg/go:1.16

USER 0

RUN apt-get update && \
  apt-get upgrade && \
  apt-get install -y --no-install-recommends \
    lsb-release \
    cmake \
    python3-distutils \
    clang-format \
    patch && \
# Install additional formatters/linters
    go install mvdan.cc/sh/v3/cmd/shfmt@v3.4.1 && \
    wget -qO- "https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.linux.x86_64.tar.xz" | tar -xJv && \
    cp "shellcheck-stable/shellcheck" /usr/bin/ && \
# Install hub-comment
    wget --quiet https://github.com/joshdk/hub-comment/releases/download/0.1.0-rc6/hub-comment_linux_amd64 && \
    install hub-comment_linux_amd64 /usr/bin/hub-comment


ENV ROX_CI_IMAGE=collector-ci-image

COPY ./static-contents/bin/bash-wrapper /bin/

RUN \
	mv /bin/bash /bin/real-bash && \
	mv /bin/bash-wrapper /bin/bash && \
    chmod 755 /bin/bash

USER circleci

# Install GCloud SDK per https://cloud.google.com/sdk/docs/downloads-interactive#linux
# Note: We DO NOT use apt-get to install it in order to be able to use the built-in
# upgrade functionality.
RUN curl https://sdk.cloud.google.com > install.sh && bash install.sh --disable-prompts

ENV PATH /home/circleci/google-cloud-sdk/bin:${PATH}

RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python3 get-pip.py
RUN \
  gcloud config set core/disable_prompts True && \
  gcloud components install gsutil -q && \
  gcloud components update -q
