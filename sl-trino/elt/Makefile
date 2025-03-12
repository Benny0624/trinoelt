################################################################################
# Build action
################################################################################

# build variables
-include build.env

# make build tag=sldatacenter/trino-elt:dev
build-trino:
	@docker build \
		--tag $${tag:-sldatacenter/trino-elt:dev} \
		--build-arg TRINO_VERSION=${TRINO_VERSION} \
		--build-arg JMX_AGENT_VERSION=${JMX_AGENT_VERSION} \
		-f docker/trino.Dockerfile .
.PHONY: build-trino

build: build-trino
.PHONY: build
