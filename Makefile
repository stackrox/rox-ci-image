ifeq ($(TAG),)
TAG=$(shell .circleci/get_tag.sh "stackrox-build")
endif
ifeq ($(ROCKSDB_TAG),)
ROCKSDB_TAG=$(shell .circleci/get_tag.sh "rocksdb")
endif

.PHONY: stackrox-build-image
stackrox-build-image:
	docker build images/ -f images/stackrox-build.Dockerfile \
	    -t stackrox/apollo-ci:$(TAG) \
		--build-arg ROCKSDB_TAG=$(ROCKSDB_TAG)

.PHONY: rocksdb-image
rocksdb-image:
	docker build images/ -f images/centos8-rocksdb.Dockerfile \
	    -t stackrox/apollo-ci:$(ROCKSDB_TAG)
