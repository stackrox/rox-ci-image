ARG BASE_TAG
FROM quay.io/rhacs-eng/apollo-ci:${BASE_TAG}

COPY test/ .
ENV CI=true
ENV CIRCLECI=true

CMD ["bats", "--print-output-on-failure", "--verbose-run", "bats/"]
