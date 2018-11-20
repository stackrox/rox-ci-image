FROM circleci/golang:1.11.2-stretch

USER 0

RUN \
	export CLOUD_SDK_REPO="cloud-sdk-stretch" && \
    echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | \
    tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    apt-key add - && \
    apt-get update -y && apt-get install google-cloud-sdk -y

USER circleci

ENV ROX_CI_IMAGE collector-ci-image
