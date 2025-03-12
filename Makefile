include local/.local.env
export

define help
Usage: make COMMAND

Main commands:
  init     Initialize basic setting (need to execute when using for the first time)
  build    Build docker images (need to be rebuilt if there are any changes in Dockerfile)
  start    Start docker services with selected profiles
  restart  Restart docker services with selected profiles
  down     Turn down docker services
  exec     Execute command in docker container
  attach   Go into docker container
  logs     Fetch the logs of a container
  run      Run a new docker container

Other commands:
  config-kafka-connect   Update connectors in kafka connect

Examples:
  make start profiles=kafka,mongo,flink
  make attach service=flink-jobmanager
  make exec service=flink-helper cmd=sql-client.sh
  make down options=-v
  ...
endef
export help

COMPOSE_FILE := $(shell echo $(shell ls local/*.docker-compose.yaml) | tr ' ' ':')

help:
	@echo "$$help"

init:
	@echo "[INIT] Install poetry if not exist"
	@brew list poetry &> /dev/null || brew install poetry
	@poetry install && poetry run pre-commit install
	@echo "[INIT] Create a shared network if it does not exist (dev-infra-internal)"
	@docker network inspect dev-infra-internal > /dev/null 2>&1 \
		|| docker network create -d bridge dev-infra-internal
.PHONY: init

build:
	@echo "[BUILD]"
ifeq ($(findstring trino-elt, $(profiles)), trino-elt)
	@make -C ./sl-trino/elt build
endif
	@COMPOSE_PROFILES=$${profiles:-$$COMPOSE_PROFILES} \
		docker compose build \
			--build-arg machine="$(shell uname -m)" \
			--build-arg environment=$(environment)
.PHONY: build

start:
	@echo "[START]"
	@COMPOSE_PROFILES=$${profiles:-$$COMPOSE_PROFILES} \
		docker compose up -d
.PHONY: start

restart:
	@echo "[RESTART]"
	@COMPOSE_PROFILES=$${profiles:-$$COMPOSE_PROFILES} \
		docker compose restart $(service)
.PHONY: restart

down:
	@echo "[DOWN]"
	@COMPOSE_PROFILES=$${profiles:-*} \
		docker compose down $(options)
.PHONY: down

exec:
	@echo "[EXEC]"
	@COMPOSE_PROFILES=$${profiles:-*} \
		docker compose exec $(service) $(cmd)

attach:
	@echo "[ATTACH]"
	@COMPOSE_PROFILES=$${profiles:-*} \
		docker compose exec $(service) bash
.PHONY: attach

logs:
	@echo "[LOGS]"
	@COMPOSE_PROFILES=$${profiles:-*} \
		docker compose logs $(service)
.PHONY: logs

run:
	@echo "[RUN]"
	@COMPOSE_PROFILES=$${profiles:-*} \
		docker compose run --rm $(service) $(cmd)
.PHONY: run

else ifeq ($(protocol_type), avro)
	@docker compose exec tidb tiup cdc cli changefeed create \
		--server=http://localhost:$$TI_CDC_PORT \
		--sink-uri="kafka://kafka-1:9092,kafka-2:9092,kafka-3:9092/ticdc-meta?protocol=avro&enable-tidb-extension=true&partition-num=3&max-message-bytes=67108864&replication-factor=1&avro-decimal-handling-mode=string&compression=gzip" \
		--schema-registry="http://kafka-schemaregistry:8081" \
		--changefeed-id="simple-avro-task" \
		--config ti-cdc/ti-cdc-sink-kafka-avro.toml
else
	$(error protocol_type must be 'canal-json' or 'avro')
endif
