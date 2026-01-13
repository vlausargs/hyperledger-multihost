#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

require_cmd jq
require_cmd configtxlator

peer_env_org1

CHANNEL_NAME="${CHANNEL_NAME:?CHANNEL_NAME not set}"
ORDERER_ADDR="orderer.${DOMAIN}:${ORDERER_PORT}"
ANCHOR_HOST="peer0.org1.${DOMAIN}"
ANCHOR_PORT="${ORG1_PEER_PORT}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "==> Fetch current channel config block (${CHANNEL_NAME})"
peer channel fetch config "$WORKDIR/config_block.pb" \
  -o "$ORDERER_ADDR" \
  -c "$CHANNEL_NAME" \
  --tls --cafile "$ORDERER_CA"

echo "==> Decode config block"
configtxlator proto_decode --input "$WORKDIR/config_block.pb" --type common.Block \
  | jq '.data.data[0].payload.data.config' > "$WORKDIR/config.json"

cp "$WORKDIR/config.json" "$WORKDIR/config_modified.json"

echo "==> Set Org1MSP anchor peers -> ${ANCHOR_HOST}:${ANCHOR_PORT}"
jq --arg host "$ANCHOR_HOST" --argjson port "$ANCHOR_PORT" \
  '(.channel_group.groups.Application.groups.Org1MSP.values.AnchorPeers.value.anchor_peers)=[{"host":$host,"port":$port}]' \
  "$WORKDIR/config_modified.json" > "$WORKDIR/config_modified2.json"
mv "$WORKDIR/config_modified2.json" "$WORKDIR/config_modified.json"

echo "==> Encode configs"
configtxlator proto_encode --input "$WORKDIR/config.json" --type common.Config --output "$WORKDIR/config.pb"
configtxlator proto_encode --input "$WORKDIR/config_modified.json" --type common.Config --output "$WORKDIR/config_modified.pb"

echo "==> Compute config update"
configtxlator compute_update \
  --channel_id "$CHANNEL_NAME" \
  --original "$WORKDIR/config.pb" \
  --updated "$WORKDIR/config_modified.pb" \
  --output "$WORKDIR/update.pb"

configtxlator proto_decode --input "$WORKDIR/update.pb" --type common.ConfigUpdate > "$WORKDIR/update.json"

echo "==> Wrap update in envelope"
echo '{"payload":{"header":{"channel_header":{"channel_id":"'"$CHANNEL_NAME"'","type":2}},"data":{"config_update":'"$(cat "$WORKDIR/update.json")"'}}}' \
  | jq . > "$WORKDIR/update_envelope.json"

configtxlator proto_encode --input "$WORKDIR/update_envelope.json" --type common.Envelope --output "$WORKDIR/update_envelope.pb"

echo "==> Submit channel update"
peer channel update \
  -o "$ORDERER_ADDR" \
  -c "$CHANNEL_NAME" \
  -f "$WORKDIR/update_envelope.pb" \
  --tls --cafile "$ORDERER_CA"
