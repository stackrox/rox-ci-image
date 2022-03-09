ARG BASE_TAG
FROM quay.io/rhacs-eng/apollo-ci:${BASE_TAG}

WORKDIR /home/circleci/test
COPY --chown=circleci:circleci test/ .
ENV CI=true
ENV CIRCLECI=true

CMD ["bats", "--print-output-on-failure", "--verbose-run", "/home/circleci/test/bats/"]
