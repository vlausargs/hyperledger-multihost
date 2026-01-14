#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"
peer_env_org1

#check peer msp
echo "==> Checking Peer MSP"
TMP=/tmp/${CHANNEL_NAME}-cfg
mkdir -p "$TMP"

peer channel fetch config "$TMP/config.block" \
  -o "orderer.${DOMAIN}:${ORDERER_PORT}" \
  -c "${CHANNEL_NAME}" \
  --tls --cafile "${ORDERER_CA}"

configtxlator proto_decode --input "$TMP/config.block" --type common.Block \
| jq -r '.data.data[0].payload.data.config
  .channel_group.groups.Application.groups.Org1MSP.values.AnchorPeers.value.anchor_peers'


echo "==> org1 peer join channel ${CHANNEL_NAME}"
peer channel join -b "channel-artifacts/${CHANNEL_NAME}.block"

# echo "==> org1 channel update"
# peer channel update \
#   -o "orderer.${DOMAIN}:${ORDERER_PORT}" \
#   -c "${CHANNEL_NAME}" \
#   -f "channel-artifacts/Org1MSPanchors.tx" \
#   --tls --cafile "${ORDERER_CA}"
