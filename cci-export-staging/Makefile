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
