REGISTRY := quay.io/rhacs-eng
APP_NAME := apollo-ci
PLATFORM := linux/amd64

ifeq ($(CENTOS_TAG),)
	CENTOS_TAG := $(shell cat config/CENTOS_TAG)
endif

ifeq ($(ROCKSDB_TAG),)
	ROCKSDB_TAG := $(shell scripts/get_tag.sh rocksdb $(CENTOS_TAG))
endif

STACKROX_TAG      := $(shell scripts/get_tag.sh "stackrox")
STACKROX_TEST_TAG := $(shell scripts/get_tag.sh "stackrox-test")
STACKROX_CCI_TAG  := $(shell scripts/get_tag.sh "stackrox-cci")
COLLECTOR_TAG     := $(shell scripts/get_tag.sh "collector")
SCANNER_TAG       := $(shell scripts/get_tag.sh "scanner")
SCANNER_TEST_TAG  := $(shell scripts/get_tag.sh "scanner-test")


tag:
	git describe --tags --abbrev=10

setup:
	@#docker buildx create --use
	docker buildx ls

build-rocksdb:
	docker buildx build --platform ${PLATFORM} --progress=plain \
		--build-arg CENTOS_TAG=$(CENTOS_TAG) \
		--build-arg ROCKSDB_TAG=$(ROCKSDB_TAG) \
		-t ${REGISTRY}/${APP_NAME}:$(ROCKSDB_TAG) \
		-f Dockerfile.rocksdb \
		--push .
	docker images --digests --format "{{json .}}" ${REGISTRY}/${APP_NAME} | jq .
	docker buildx imagetools inspect ${REGISTRY}/${APP_NAME}:${ROCKSDB_TAG}

build-stackrox:
	docker buildx build --platform ${PLATFORM} --progress=plain \
		--build-arg CENTOS_TAG=$(CENTOS_TAG) \
		--build-arg ROCKSDB_TAG=$(ROCKSDB_TAG) \
		-t ${REGISTRY}/${APP_NAME}:$(STACKROX_TAG) \
		-f Dockerfile.stackrox.amd64 \
		--push .
	docker images --digests --format "{{json .}}" ${REGISTRY}/${APP_NAME} | jq .
	docker buildx imagetools inspect ${REGISTRY}/${APP_NAME}:${STACKROX_TAG}

build-stackrox-test:
	docker buildx build --platform ${PLATFORM} --progress=plain \
		--build-arg BASE_TAG=$(STACKROX_TAG) \
		-t ${REGISTRY}/${APP_NAME}:$(STACKROX_TEST_TAG) \
		-f Dockerfile.stackrox-test \
		--push .
	docker images --digests --format "{{json .}}" ${REGISTRY}/${APP_NAME} | jq .
	docker buildx imagetools inspect ${REGISTRY}/${APP_NAME}:${STACKROX_TEST_TAG}

build-collector:
	docker buildx build --platform ${PLATFORM} --progress=plain \
		-f Dockerfile.collector \
		-t ${REGISTRY}/${APP_NAME}:$(COLLECTOR_TAG) \
		--push .
	docker images --digests --format "{{json .}}" ${REGISTRY}/${APP_NAME} | jq .
	docker buildx imagetools inspect ${REGISTRY}/${APP_NAME}:${COLLECTOR_TAG}

build-scanner:
	docker buildx build --platform ${PLATFORM} --progress=plain \
		--build-arg CENTOS_TAG=$(CENTOS_TAG) \
		-f Dockerfile.scanner \
		-t ${REGISTRY}/${APP_NAME}:$(SCANNER_TAG) \
		--push .
	docker images --digests --format "{{json .}}" ${REGISTRY}/${APP_NAME} | jq .
	docker buildx imagetools inspect ${REGISTRY}/${APP_NAME}:${SCANNER_TAG}

build-scanner-test:
	docker buildx build --platform ${PLATFORM} --progress=plain \
		--build-arg BASE_TAG=$(SCANNER_TAG) \
		-f Dockerfile.scanner-test \
		-t ${REGISTRY}/${APP_NAME}:$(SCANNER_TEST_TAG) \
		--push .
	docker images --digests --format "{{json .}}" ${REGISTRY}/${APP_NAME} | jq .
	docker buildx imagetools inspect ${REGISTRY}/${APP_NAME}:${SCANNER_TEST_TAG}

gha-list-workflows:
	gh workflow list --all

gha-enable-workflows:
	gh workflow enable stackrox || true
	gh workflow enable collector || true
	gh workflow enable scanner || true
	gh workflow enable jenkins || true

gha-disable-workflows:
	gh workflow disable stackrox || true
	gh workflow disable collector || true
	gh workflow disable scanner || true
	gh workflow disable jenkins || true

github-workflow-syntax-check:
	yq e .github/workflows/*.yml

lint-shell:
	find scripts -name '*.sh' | xargs shellcheck -P scripts

# https://github.com/bats-core/bats-core
# https://github.com/bats-core/bats-docs
bats: TEST_REPORT=/tmp/bats-report    # bats expects output directory to exist
bats: TEST_OUTPUTS=/tmp/bats-outputs  # bats creates the specified directory
bats:
	mkdir -p $(TEST_REPORT) && rm -rf $(TEST_OUTPUTS)
	bats --recursive --timing --formatter pretty --verbose-run \
		--output $(TEST_REPORT) --report-formatter tap13 \
		--gather-test-outputs-in $(TEST_OUTPUTS) \
		$(PWD)/test/
