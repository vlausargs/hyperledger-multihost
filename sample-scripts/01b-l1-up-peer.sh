#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
docker compose -f compose/docker-compose.laptop1-peer.yaml up -d
