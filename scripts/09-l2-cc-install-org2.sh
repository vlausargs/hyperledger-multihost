#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
peer_env_org2
peer lifecycle chaincode install "channel-artifacts/${CC_NAME}.tar.gz"
