StackRox Container Images for CI Workflows
------------------------------------------

* https://github.com/stackrox/rox-ci-image/
* https://github.com/stackrox/rox-ci-image/actions
* https://app.circleci.com/pipelines/github/stackrox/rox-ci-image
* https://quay.io/repository/rhacs-eng/apollo-ci


Image Hierarchy
---------------

### Images based on //config/CENTOS\_TAG

```mermaid
graph TD;
  quay.io/centos/centos:stream8 --> quay.io/rhacs-eng/apollo-ci:collector;
  quay.io/centos/centos:stream8 --> quay.io/rhacs-eng/apollo-ci:rocksdb;
  quay.io/centos/centos:stream8 --> quay.io/rhacs-eng/apollo-ci:scanner;
  quay.io/centos/centos:stream8 --> quay.io/rhacs-eng/apollo-ci:stackrox;
  quay.io/rhacs-eng/apollo-ci:ROCKSDB_TAG --> quay.io/rhacs-eng/apollo-ci:stackrox;
```

### Images based on apollo-ci:BASE\_TAG

See build-and-push-image.sh, _BASE_TAG_ is the current tag for the apollo-ci variant.

```mermaid
graph TD;
  quay.io/rhacs-eng/apollo-ci:BASE_TAG --> quay.io/rhacs-eng/apollo-ci:scanner-test;
  quay.io/rhacs-eng/apollo-ci:BASE_TAG --> quay.io/rhacs-eng/apollo-ci:stackrox-test;
```

### Images based on ubuntu:22.04

```mermaid
graph TD;
  ubuntu:22.04 --> quay.io/rhacs-eng/apollo-ci:jenkins-plugin;
```
