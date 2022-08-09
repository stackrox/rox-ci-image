ifeq ($(STACKROX_CENTOS_TAG),)
STACKROX_CENTOS_TAG=$(shell cat STACKROX_CENTOS_TAG)
endif
ifeq ($(ROCKSDB_TAG),)
ROCKSDB_TAG=$(shell .circleci/get_tag.sh "rocksdb" "$(STACKROX_CENTOS_TAG)")
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
		--build-arg STACKROX_CENTOS_TAG=$(STACKROX_CENTOS_TAG) \
		-f images/rocksdb.Dockerfile \
		images/

STACKROX_BUILD_TAG=$(shell .circleci/get_tag.sh "stackrox-build")

.PHONY: stackrox-build-image
stackrox-build-image:
	$(DOCKER) build \
	    -t stackrox/apollo-ci:$(STACKROX_BUILD_TAG) \
	    -t quay.io/$(QUAY_REPO)/apollo-ci:$(STACKROX_BUILD_TAG) \
		--build-arg ROCKSDB_TAG=$(ROCKSDB_TAG) \
		--build-arg STACKROX_CENTOS_TAG=$(STACKROX_CENTOS_TAG) \
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

# Generic targets
# ===============

# Set BASE_TAG for certain images, matching against the image target.
scanner-test-image__base_tag := scanner-build

.PHONY: %-image
%-image: images/%.Dockerfile
	$(DOCKER) build \
	    $(if ${$@__base_tag},--build-arg BASE_TAG=$$(.circleci/get_tag.sh ${$@__base_tag} "${STACKROX_CENTOS_TAG}")) \
	    $(foreach arg,${$@__additional_args},--build-arg ${arg}) \
	    --tag quay.io/rhacs-eng/apollo-ci:$$(.circleci/get_tag.sh $@ "${STACKROX_CENTOS_TAG}") \
	    --file $< \
            images/
