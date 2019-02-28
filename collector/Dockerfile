FROM circleci/golang:1.11.2-stretch

USER 0

RUN export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get install -y --no-install-recommends lsb-release apt-cacher-ng debian-keyring apt-transport-https dirmngr wget curl

ADD docker-gpg-key.asc /

RUN KN=/docker-gpg-key.asc && apt-key add $KN && rm $KN

RUN groupadd -g 999 docker

RUN echo 'deb [arch=amd64] https://download.docker.com/linux/debian stretch stable' >> /etc/apt/sources.list

# Install GCloud SDK, copied from
# https://cloud.google.com/sdk/docs/quickstart-debian-ubuntu#before-you-begin
RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update -y && apt-get install google-cloud-sdk -y

RUN apt-get install docker-ce sudo --no-install-recommends

RUN apt-get update && apt-get install -y --no-install-recommends cmake

RUN adduser circleci docker

RUN adduser circleci sudo

ENV ROX_CI_IMAGE=collector-ci-image

USER circleci
