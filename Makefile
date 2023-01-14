ifeq ($(STACKROX_CENTOS_TAG),)
STACKROX_CENTOS_TAG=$(shell cat STACKROX_CENTOS_TAG)
endif
ifeq ($(ROCKSDB_TAG),)
ROCKSDB_TAG=$(shell scripts/get_tag.sh "rocksdb" "$(STACKROX_CENTOS_TAG)")
endif
ifeq ($(DOCKER),)
DOCKER=docker
endif
QUAY_REPO=rhacs-eng

.PHONY: rocksdb-image
rocksdb-image:
	$(DOCKER) build \
	    -t quay.io/$(QUAY_REPO)/apollo-ci:$(ROCKSDB_TAG) \
		--build-arg STACKROX_CENTOS_TAG=$(STACKROX_CENTOS_TAG) \
		-f images/rocksdb.Dockerfile \
		images/

STACKROX_BUILD_TAG=$(shell scripts/get_tag.sh "stackrox-build")

.PHONY: stackrox-build-image
stackrox-build-image:
	$(DOCKER) build \
	    -t quay.io/$(QUAY_REPO)/apollo-ci:$(STACKROX_BUILD_TAG) \
		--build-arg ROCKSDB_TAG=$(ROCKSDB_TAG) \
		--build-arg STACKROX_CENTOS_TAG=$(STACKROX_CENTOS_TAG) \
		-f images/stackrox-build.Dockerfile \
		images/

STACKROX_TEST_TAG=$(shell scripts/get_tag.sh "stackrox-test")

.PHONY: stackrox-test-image
stackrox-test-image:
	$(DOCKER) build \
	    -t quay.io/$(QUAY_REPO)/apollo-ci:$(STACKROX_TEST_TAG) \
		--build-arg BASE_TAG=$(STACKROX_BUILD_TAG) \
		-f images/stackrox-test.Dockerfile \
		images/

.PHONY: test-cci-export
test-cci-export:
	$(DOCKER) build \
	    -t test-cci-export \
		--build-arg BASE_TAG=$(STACKROX_TEST_TAG) \
		-f images/test.cci-export.Dockerfile \
		images/
	$(DOCKER) run \
		-it \
		test-cci-export

.PHONY: collector-image
collector-image:
	$(DOCKER) build \
	    -t quay.io/$(QUAY_REPO)/apollo-ci:$(shell scripts/get_tag.sh "collector") \
		-f images/collector.Dockerfile \
		images/

.PHONY: scanner-build-image
scanner-build-image:
	$(DOCKER) build \
	    -t quay.io/$(QUAY_REPO)/apollo-ci:$(shell scripts/get_tag.sh "scanner-build") \
	    -f images/scanner-build.Dockerfile \
	    images/

.PHONY: scanner-test-image
scanner-test-image:
	$(DOCKER) build \
	    --build-arg BASE_TAG=$(shell scripts/get_tag.sh "scanner-build") \
	    -t quay.io/$(QUAY_REPO)/apollo-ci:$(shell scripts/get_tag.sh "scanner-test") \
	    -f images/scanner-test.Dockerfile \
	    images/

.PHONY: jenkins-plugin-image
jenkins-plugin-image:
	$(DOCKER) build \
	    -t quay.io/$(QUAY_REPO)/apollo-ci:$(shell scripts/get_tag.sh "jenkins-plugin") \
	    -f images/jenkins-plugin.Dockerfile \
	    images/
