#!/usr/bin/env bash
set -euo pipefail

# Post-deployment probe for the public ingress contract.
# Accepts 2xx, 3xx and 4xx because authentication policies and empty route tables
# legitimately return 401/403/404. A 5xx or an empty response is a failure.

api_url="${1:-}"
console_url="${2:-}"

if [[ -z "$api_url" ]]; then
  echo "usage: $0 <api-url> [console-url]" >&2
  echo "example: $0 https://api.example.com https://console.example.com" >&2
  exit 2
fi

check() {
  local url="$1"
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "$url" || true)"

  if [[ "$code" =~ ^[234] ]]; then
    echo "  PASS $url -> $code"
  else
    echo "  FAIL $url -> ${code:-no response}"
    return 1
  fi
}

echo "== ingress smoke test =="
check "$api_url"
if [[ -n "$console_url" ]]; then
  check "$console_url"
fi
