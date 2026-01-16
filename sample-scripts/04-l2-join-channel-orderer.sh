#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-env.sh"

BLOCK="channel-artifacts/${CHANNEL_NAME}.block"

# because this run first it use channel join instead of update
echo "==> orderer join via osnadmin (channel participation)"
osnadmin channel join \
  --channelID "${CHANNEL_NAME}" \
  --config-block "${BLOCK}" \
  -o "orderer.${DOMAIN}:${ORDERER_ADMIN_PORT}" \
  --ca-file "${ORDERER_ADMIN_TLS_CA}" \
  --client-cert "${ORDERER_ADMIN_TLS_CLIENT_CERT}" \
  --client-key "${ORDERER_ADMIN_TLS_CLIENT_KEY}"

echo "==> list channels"
osnadmin channel list \
  -o "orderer.${DOMAIN}:${ORDERER_ADMIN_PORT}" \
  --ca-file "${ORDERER_ADMIN_TLS_CA}" \
  --client-cert "${ORDERER_ADMIN_TLS_CLIENT_CERT}" \
  --client-key "${ORDERER_ADMIN_TLS_CLIENT_KEY}"
