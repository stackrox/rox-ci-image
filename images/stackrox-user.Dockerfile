ARG BASE_TAG
FROM quay.io/rhacs-eng/apollo-ci:${BASE_TAG}

RUN groupadd stackrox && \
    useradd --gid stackrox --shell /bin/bash --create-home stackrox
