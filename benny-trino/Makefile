################################################################################
# Build action
################################################################################

# build variables
-include build.env

# make build tag=benny-trino/trino:dev
build-trino:
	@docker build \
		--tag $${tag:-benny-trino/trino:dev} \
		--build-arg TRINO_VERSION=${TRINO_VERSION} \
		--build-arg OPENJDK_VERSION=${OPENJDK_VERSION} \
		-f docker/trino.Dockerfile .
.PHONY: build-trino

build: build-trino
.PHONY: build
