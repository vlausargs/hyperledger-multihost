#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
peer_env_org2

peer channel join -b "channel-artifacts/${CHANNEL_NAME}.block"

peer channel update \
  -o "orderer.${DOMAIN}:${ORDERER_PORT}" \
  -c "${CHANNEL_NAME}" \
  -f "channel-artifacts/Org2MSPanchors.tx" \
  --tls --cafile "${ORDERER_CA}"
