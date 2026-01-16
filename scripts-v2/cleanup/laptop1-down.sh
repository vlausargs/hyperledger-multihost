#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

echo "==> Stopping and removing laptop1 services..."
docker compose -f compose/docker-compose.laptop1-org1-ca.yaml down -v
docker compose -f compose/docker-compose.laptop1-org1-peer.yaml down -v

echo "==> Laptop1 cleanup complete"
