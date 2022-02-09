ARG BASE_TAG
FROM quay.io/rhacs-eng/apollo-ci:${BASE_TAG}

# Install Circle CI tools
COPY circleci-tools /opt/circleci-tools
ENV PATH=/opt/circleci-tools:$PATH
WORKDIR /opt/circleci-tools
RUN set -ex \
  && sudo chown -R circleci /opt/circleci-tools \
  && cd /opt/circleci-tools \
  && npm install \
  && command -v pull-workflow-output.js \
  && command -v check-for-sensitive-env-values.js

USER circleci
WORKDIR /home/circleci
