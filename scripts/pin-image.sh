#!/usr/bin/env bash
set -euo pipefail

# Resolves a mutable image tag to an immutable registry digest.
# Usage: ./scripts/pin-image.sh <image:tag>

image="${1:-}"
if [[ -z "$image" ]]; then
  echo "usage: $0 <image:tag>" >&2
  echo "example: $0 higress-registry.cn-hangzhou.cr.aliyuncs.com/higress/all-in-one:latest" >&2
  exit 2
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is required" >&2
  exit 1
fi

digest="$(docker buildx imagetools inspect "$image" --format '{{json .Manifest.Digest}}' | tr -d '"')"
if [[ -z "$digest" ]]; then
  echo "error: could not resolve a digest for $image" >&2
  exit 1
fi

repo="${image%@*}"
repo="${repo%:*}"
printf '%s@%s\n' "$repo" "$digest"
