#!/usr/bin/env bash
set -euo pipefail

# Captures the Higress state volume into a portable archive.
#
# For a strictly consistent snapshot, quiesce the service before invocation:
#   docker compose stop higress
#   ./scripts/backup.sh
#   docker compose start higress

cd "$(dirname "${BASH_SOURCE[0]}")/.."

container_id="${HIGRESS_CONTAINER_ID:-}"
if [[ -z "$container_id" ]]; then
  ids="$(docker ps --filter 'label=com.docker.compose.service=higress' --format '{{.ID}}')"
  count="$(printf '%s\n' "$ids" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$count" != "1" ]]; then
    echo "error: found $count higress containers; set HIGRESS_CONTAINER_ID explicitly" >&2
    exit 1
  fi
  container_id="$ids"
fi

volume_name="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Name}}{{end}}{{end}}' "$container_id")"
if [[ -z "$volume_name" ]]; then
  echo "error: could not resolve the /data volume for the higress container" >&2
  exit 1
fi

out_dir="${1:-backups}"
mkdir -p "$out_dir"
out_file="$out_dir/higress-data-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"

docker run --rm \
  -v "${volume_name}:/data:ro" \
  -v "$(cd "$out_dir" && pwd):/backup" \
  alpine:3.20 \
  sh -c "tar czf /backup/$(basename "$out_file") -C /data ."

echo "backup written: $out_file"
echo "volume: $volume_name"
