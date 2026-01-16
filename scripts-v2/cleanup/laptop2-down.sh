#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

echo "==> Stopping and removing laptop2 services..."
docker compose -f compose/docker-compose.laptop2.yaml down -v
docker compose -f compose/docker-compose.laptop2-ca-orderer.yaml down -v
docker compose -f compose/docker-compose.laptop2-ca-org2.yaml down -v
docker compose -f compose/docker-compose.laptop2-ca-org3.yaml down -v
docker compose -f compose/docker-compose.laptop2-orderer.yaml down -v
docker compose -f compose/docker-compose.laptop2-org2-peer.yaml down -v
docker compose -f compose/docker-compose.laptop2-org3-peer.yaml down -v

echo "==> Laptop2 cleanup complete"
