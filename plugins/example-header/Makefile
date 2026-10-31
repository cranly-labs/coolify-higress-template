# Reference plugin build contract.
PLUGIN_NAME ?= example-header
GO ?= go

.DEFAULT_GOAL := build
.PHONY: help tidy build clean docker-build

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

tidy: ## Resolve Go module metadata
	$(GO) mod tidy

build: tidy ## Compile plugin.wasm for wasip1
	GOOS=wasip1 GOARCH=wasm $(GO) build -buildmode=c-shared -o plugin.wasm .

clean: ## Remove local build output
	rm -f plugin.wasm

# Local convenience target. Production and CI use scripts/build-plugin.sh.
docker-build: build ## Build a local OCI image
	docker buildx build \
		--platform $${PLUGIN_PLATFORM:-linux/amd64} \
		-f ../Dockerfile.plugin \
		-t $${PLUGIN_IMAGE:-higress-plugin-example-header:dev} \
		.
