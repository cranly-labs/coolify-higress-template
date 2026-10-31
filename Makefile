SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help config preflight up down logs ps smoke build-plugin

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nHigress Coolify Reference Architecture\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  %-16s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

config: ## Validate the Compose model
	docker compose config

preflight: ## Validate environment and deployment contract
	./scripts/preflight.sh

up: ## Start the runtime locally or on a host
	docker compose up -d

down: ## Stop and remove the runtime
	docker compose down

logs: ## Follow runtime logs
	docker compose logs -f --tail=200

ps: ## Show runtime status
	docker compose ps

smoke: ## Probe public ingress (API_URL and CONSOLE_URL required)
	@test -n "$(API_URL)" || (echo "set API_URL=https://api.example.com" >&2; exit 2)
	@test -n "$(CONSOLE_URL)" || (echo "set CONSOLE_URL=https://console.example.com" >&2; exit 2)
	./scripts/smoke-test.sh "$(API_URL)" "$(CONSOLE_URL)"

build-plugin: ## Build and publish a plugin artifact
	@test -n "$(PLUGIN_DIR)" || (echo "set PLUGIN_DIR=plugins/example-header" >&2; exit 2)
	@test -n "$(PLUGIN_IMAGE)" || (echo "set PLUGIN_IMAGE=registry/name:tag" >&2; exit 2)
	./scripts/build-plugin.sh "$(PLUGIN_DIR)" "$(PLUGIN_IMAGE)"
