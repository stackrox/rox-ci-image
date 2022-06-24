ifeq ($(CENTOS_TAG),)
CENTOS_TAG=$(shell cat CENTOS_TAG)
endif
ifeq ($(ROCKSDB_TAG),)
ROCKSDB_TAG=$(shell .circleci/get_tag.sh "rocksdb" "$(CENTOS_TAG)")
endif
ifeq ($(DOCKER),)
DOCKER=docker
endif
QUAY_REPO=rhacs-eng

.PHONY: rocksdb-image
rocksdb-image:
	$(DOCKER) build \
	    -t stackrox/apollo-ci:$(ROCKSDB_TAG) \
	    -t quay.io/$(QUAY_REPO)/apollo-ci:$(ROCKSDB_TAG) \
		--build-arg CENTOS_TAG=$(CENTOS_TAG) \
		-f images/rocksdb.Dockerfile \
		images/

STACKROX_BUILD_TAG=$(shell .circleci/get_tag.sh "stackrox-build")

.PHONY: stackrox-build-image
stackrox-build-image:
	$(DOCKER) build \
	    -t stackrox/apollo-ci:$(STACKROX_BUILD_TAG) \
	    -t quay.io/$(QUAY_REPO)/apollo-ci:$(STACKROX_BUILD_TAG) \
		--build-arg ROCKSDB_TAG=$(ROCKSDB_TAG) \
		--build-arg CENTOS_TAG=$(CENTOS_TAG) \
		-f images/stackrox-build.Dockerfile \
		images/

STACKROX_TEST_TAG=$(shell .circleci/get_tag.sh "stackrox-test")

.PHONY: stackrox-test-image
stackrox-test-image:
	$(DOCKER) build \
	    -t stackrox/apollo-ci:$(STACKROX_TEST_TAG) \
	    -t quay.io/$(QUAY_REPO)/apollo-ci:$(STACKROX_TEST_TAG) \
		--build-arg BASE_TAG=$(STACKROX_BUILD_TAG) \
		-f images/stackrox-test.Dockerfile \
		images/

STACKROX_TEST_CCI_TAG=$(shell .circleci/get_tag.sh "stackrox-test-cci")

.PHONY: stackrox-test-cci-image
stackrox-test-cci-image:
	$(DOCKER) build \
	    -t stackrox/apollo-ci:$(STACKROX_TEST_CCI_TAG) \
	    -t quay.io/$(QUAY_REPO)/apollo-ci:$(STACKROX_TEST_CCI_TAG) \
		--build-arg BASE_TAG=$(STACKROX_TEST_TAG) \
		-f images/circleci.Dockerfile \
		images/

.PHONY: test-cci-export
test-cci-export:
	$(DOCKER) build \
	    -t test-cci-export \
		--build-arg BASE_TAG=$(STACKROX_TEST_CCI_TAG) \
		-f images/test.cci-export.Dockerfile \
		images/
	$(DOCKER) run \
		-it \
		test-cci-export

.PHONY: collector-test-image
collector-test-image:
	$(DOCKER) build \
		-f images/collector.Dockerfile \
		images/

.PHONY: github-workflow-syntax-check
github-workflow-syntax-check:
	yq e .github/workflows/hello-world.yml
	yq e .github/workflows/hello-world.yml
