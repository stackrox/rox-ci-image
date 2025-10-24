ARG BASE_TAG
FROM quay.io/stackrox-io/apollo-ci:${BASE_TAG}

COPY test/ .
ENV CI=true
ENV CIRCLECI=true

CMD ["bats", "--print-output-on-failure", "--verbose-run", "bats/"]
