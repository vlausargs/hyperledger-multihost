#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

peer_env_org1
peer lifecycle chaincode install "channel-artifacts/${CC_NAME}.tar.gz"
