#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"
docker compose -f compose/docker-compose.laptop2-ca-org2.yaml up -d
docker compose -f compose/docker-compose.laptop2-ca-org3.yaml up -d
docker compose -f compose/docker-compose.laptop2-ca-orderer.yaml up -d
