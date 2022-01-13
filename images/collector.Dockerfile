FROM cimg/go:1.16.4

USER 0

RUN apt-get update && apt-get install -y --no-install-recommends lsb-release cmake python3-distutils

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
