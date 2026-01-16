#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
peer_env_org2

PKG_ID="$(query_package_id "${CC_LABEL}")"
[ -n "${PKG_ID}" ] || { echo "Package ID not found for label ${CC_LABEL}. Did you install?"; exit 1; }

# Increase delivery client timeout to prevent timeout when fetching blocks from orderer
export CORE_PEER_DELIVERYCLIENT_TIMEOUT=300s
export CORE_PEER_CLIENT_TIMEOUT=300s

peer lifecycle chaincode approveformyorg \
  -o "orderer.${DOMAIN}:${ORDERER_PORT}" \
  --channelID "${CHANNEL_NAME}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --package-id "${PKG_ID}" \
  --sequence "${CC_SEQUENCE}" \
  --signature-policy "${CC_ENDORSEMENT_POLICY}" \
  --tls --cafile "${ORDERER_CA}"
