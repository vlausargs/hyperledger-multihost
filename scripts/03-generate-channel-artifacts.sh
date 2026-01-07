#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-env.sh"

mkdir -p channel-artifacts

echo "==> Generate channel block"
configtxgen -profile ThreeOrgsChannel \
  -channelID "${CHANNEL_NAME}" \
  -outputBlock "channel-artifacts/${CHANNEL_NAME}.block"

echo "==> Generate anchor peer updates"
configtxgen -profile ThreeOrgsChannel -channelID "${CHANNEL_NAME}" \
  -asOrg Org1MSP -outputAnchorPeersUpdate "channel-artifacts/Org1MSPanchors.tx"
configtxgen -profile ThreeOrgsChannel -channelID "${CHANNEL_NAME}" \
  -asOrg Org2MSP -outputAnchorPeersUpdate "channel-artifacts/Org2MSPanchors.tx"
configtxgen -profile ThreeOrgsChannel -channelID "${CHANNEL_NAME}" \
  -asOrg Org3MSP -outputAnchorPeersUpdate "channel-artifacts/Org3MSPanchors.tx"

echo "Artifacts generated in channel-artifacts/"
