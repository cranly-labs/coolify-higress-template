#!/usr/bin/env bash
set -euo pipefail

# Builds and publishes a Higress Proxy-Wasm plugin as an OCI artifact.
#
# Modes:
#   default             host Go/TinyGo toolchain, package with Dockerfile.plugin
#   BUILD_IN_DOCKER=1   reproducible in-Docker build with Dockerfile.plugin-build
#   PUSH=0              build locally without publishing
#
# Usage: ./scripts/build-plugin.sh <plugin-dir> <image-ref>

usage() {
  echo "usage: $0 <plugin-dir> <image-ref>" >&2
  echo "example: $0 plugins/example-header registry.example.com/gateway/plugin:0.1.0" >&2
}

plugin_dir="${1:-}"
image_ref="${2:-}"

if [[ -z "$plugin_dir" || -z "$image_ref" ]]; then
  usage
  exit 2
fi

if [[ ! -f "$plugin_dir/Makefile" ]]; then
  echo "error: $plugin_dir does not expose a plugin Makefile" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_dir="$(cd "$plugin_dir" && pwd)"
dockerfile="$repo_root/plugins/Dockerfile.plugin"

platform="${PLUGIN_PLATFORM:-linux/amd64}"

if [[ "${BUILD_IN_DOCKER:-0}" == "1" ]]; then
  # Toolchain isolation: TinyGo runs in the builder stage; only the artifact
  # reaches the final scratch image.
  dockerfile="$repo_root/plugins/Dockerfile.plugin-build"
else
  make -C "$plugin_dir" build

  if [[ ! -f "$plugin_dir/plugin.wasm" ]]; then
    echo "error: $plugin_dir/plugin.wasm was not produced" >&2
    exit 1
  fi
fi

echo "building $image_ref for $platform"
if [[ "${PUSH:-1}" == "1" ]]; then
  docker buildx build \
    --platform "$platform" \
    -f "$dockerfile" \
    -t "$image_ref" \
    --push \
    "$plugin_dir"
else
  docker buildx build \
    --platform "$platform" \
    -f "$dockerfile" \
    -t "$image_ref" \
    "$plugin_dir"
fi
