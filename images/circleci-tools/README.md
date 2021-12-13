These scripts provide a sanity check that Circle CI build output does not
contain leaked sensitive environment values.

## Adding to a repo

Add an executor like:

```
env-check:
  parameters:
    resource_class:
      type: string
      default: small
  resource_class: << parameters.resource_class >>
  docker:
    - image: quay.io/rhacs-eng/apollo-ci:env-check-0.3.20
      auth:
        username: $QUAY_RHACS_ENG_RO_USERNAME
        password: $QUAY_RHACS_ENG_RO_PASSWORD
  working_directory: /tmp
```

Add a job like:

```
check-for-sensitive-data:
  executor: env-check
  steps:
    - run:
        name: Check build output for sensitive data
        command: |
          export SKIP_KEYS=JUSTMINE:ANDMOREOFMINE
          check-build-output-for-env-values.sh
```

And add that job to the tail end of the build where you want it to run (e.g. for
rox):

```
- check-for-sensitive-data:
    context:
      // add any context that is used anywhere in the build
      - aws-setup
      - com-redhat-cloud
      - custom-executor-pull
      - docker-io-push
      - quay-rhacs-eng-readonly
      - quay-rhacs-eng-readwrite
    requires:
      // depend on the slowest final jobs
      - gke-api-e2e-tests
      - openshift-4-api-e2e-tests
```
