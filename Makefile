ifeq ($(DOCKER),)
DOCKER=docker
endif
QUAY_REPO=rhacs-eng

STACKROX_BUILD_TAG=$(shell scripts/get_tag.sh "stackrox-build")

.PHONY: stackrox-build-image
stackrox-build-image:
	$(DOCKER) build \
		--platform linux/amd64 \
		-t quay.io/$(QUAY_REPO)/apollo-ci:$(STACKROX_BUILD_TAG) \
		-f images/stackrox-build.Dockerfile \
		images/

STACKROX_TEST_TAG=$(shell scripts/get_tag.sh "stackrox-test")

.PHONY: stackrox-test-image
stackrox-test-image:
	$(DOCKER) build \
		--platform linux/amd64 \
		-t quay.io/$(QUAY_REPO)/apollo-ci:$(STACKROX_TEST_TAG) \
		--build-arg BASE_TAG=$(STACKROX_BUILD_TAG) \
		-f images/stackrox-test.Dockerfile \
		images/

STACKROX_UI_TEST_TAG=$(shell scripts/get_tag.sh "stackrox-ui-test")

.PHONY: stackrox-ui-test-image
stackrox-ui-test-image:
	$(DOCKER) build \
		--platform linux/amd64 \
		-t quay.io/$(QUAY_REPO)/apollo-ci:$(STACKROX_UI_TEST_TAG) \
		--build-arg BASE_TAG=$(STACKROX_UI_TEST_TAG) \
		-f images/stackrox-ui-test.Dockerfile \
		images/

.PHONY: test-cci-export
test-cci-export:
	$(DOCKER) build \
		--platform linux/amd64 \
		-t test-cci-export \
		--build-arg BASE_TAG=$(STACKROX_TEST_TAG) \
		-f images/test.cci-export.Dockerfile \
		images/
	$(DOCKER) run \
		--rm \
		test-cci-export

.PHONY: scanner-build-image
scanner-build-image:
	$(DOCKER) build \
		--platform linux/amd64 \
		-t quay.io/$(QUAY_REPO)/apollo-ci:$(shell scripts/get_tag.sh "scanner-build") \
		-f images/scanner-build.Dockerfile \
		images/

.PHONY: scanner-test-image
scanner-test-image:
	$(DOCKER) build \
		--platform linux/amd64 \
		--build-arg BASE_TAG=$(shell scripts/get_tag.sh "scanner-build") \
		-t quay.io/$(QUAY_REPO)/apollo-ci:$(shell scripts/get_tag.sh "scanner-test") \
		-f images/scanner-test.Dockerfile \
		images/

.PHONY: jenkins-plugin-image
jenkins-plugin-image:
	$(DOCKER) build \
		--platform linux/amd64 \
		-t quay.io/$(QUAY_REPO)/apollo-ci:$(shell scripts/get_tag.sh "jenkins-plugin") \
		-f images/jenkins-plugin.Dockerfile \
		images/
