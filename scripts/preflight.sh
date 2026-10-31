#!/usr/bin/env bash
set -euo pipefail

# Validates the deployment contract before a Coolify rollout.
# Checks tooling, Compose model, immutable image reference, secret strength and
# platform compatibility.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail=0
warn=0

say()  { printf '%s\n' "$*"; }
ok()   { printf '  PASS %s\n' "$*"; }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail + 1)); }
warn() { printf '  WARN %s\n' "$*"; warn=$((warn + 1)); }

say "== Higress Coolify preflight =="

if ! command -v docker >/dev/null 2>&1; then
  bad "docker is not installed"
else
  ok "docker found"
fi

if ! docker compose version >/dev/null 2>&1; then
  bad "docker compose plugin is not available"
else
  ok "docker compose found"
fi

say "-- compose model --"
if docker compose config >/dev/null 2>&1; then
  ok "docker-compose.yml is valid"
else
  bad "docker-compose.yml is invalid or required environment variables are missing"
fi

say "-- runtime reference --"
if [[ -z "${HIGRESS_IMAGE:-}" ]]; then
  bad "HIGRESS_IMAGE is empty"
else
  ok "HIGRESS_IMAGE is set"
  case "$HIGRESS_IMAGE" in
    *:latest) warn "HIGRESS_IMAGE uses :latest; production requires a tag@sha256 digest" ;;
    *@sha256:*) ok "image is pinned by digest" ;;
    *) warn "image is pinned by tag, not digest; acceptable only for immutable tags" ;;
  esac
fi

say "-- secrets --"
secret="${HIGRESS_CONSOLE_OPENAPI_JWT_SECRET:-}"
if [[ ${#secret} -lt 32 ]]; then
  bad "HIGRESS_CONSOLE_OPENAPI_JWT_SECRET must be at least 32 characters"
else
  ok "JWT secret length is ${#secret}"
fi

password="${HIGRESS_CONSOLE_ADMIN_PASSWORD:-}"
if [[ ${#password} -lt 16 ]]; then
  bad "HIGRESS_CONSOLE_ADMIN_PASSWORD must be at least 16 characters"
else
  ok "admin password length is ${#password}"
fi

say "-- platform --"
platform="${HIGRESS_PLATFORM:-linux/amd64}"
ok "configured platform: $platform"
if [[ "$(uname -m)" == "arm64" && "$platform" == "linux/amd64" ]]; then
  warn "host is arm64 while image platform is linux/amd64; verify image availability"
fi

say
if [[ $fail -gt 0 ]]; then
  say "result: $fail error(s), $warn warning(s)"
  exit 1
fi
say "result: pass, $warn warning(s)"
