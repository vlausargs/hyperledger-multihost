#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-env.sh"

mkdir -p channel-artifacts

echo "==> Package chaincode"
peer lifecycle chaincode package "channel-artifacts/${CC_NAME}.tar.gz" \
  --path "${CC_SRC_PATH}" \
  --lang "${CC_LANG}" \
  --label "${CC_LABEL}"

echo "Package created: channel-artifacts/${CC_NAME}.tar.gz"
