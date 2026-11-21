SHELL := /bin/sh
.DEFAULT_GOAL := all

SRC_DIR := srcs
ENV_FILE := $(SRC_DIR)/.env
COMPOSE_FILE := $(SRC_DIR)/docker-compose.yml

DOCKER ?= sudo docker
COMPOSE := $(DOCKER) compose --project-directory $(SRC_DIR) --env-file $(ENV_FILE) -f $(COMPOSE_FILE)

.PHONY: all check-env prepare config build up down ps logs

all: up

check-env:
	@test -f "$(ENV_FILE)" || { echo "Missing $(ENV_FILE): copy $(SRC_DIR)/.env.example to $(ENV_FILE)"; exit 1; }

prepare: check-env
	@set -eu; \
	  . ./$(ENV_FILE); \
	  test "$${HOST_LOGIN:-}" = "$$(id -un)" || { echo "HOST_LOGIN must match the VM user"; exit 1; }; \
	  sudo install -d -m 0755 "/home/$$HOST_LOGIN/data/mariadb" "/home/$$HOST_LOGIN/data/wordpress"

config: check-env
	@$(COMPOSE) config --quiet

build: prepare
	@$(COMPOSE) build

up: prepare
	@$(COMPOSE) up -d --build

down: check-env
	@$(COMPOSE) down

ps: check-env
	@$(COMPOSE) ps

logs: check-env
	@$(COMPOSE) logs -f