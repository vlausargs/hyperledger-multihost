#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

sudo chown $USER:$USER "${ROOT_DIR}/organizations" -R

./fabric-enroller/fabric-enroller enroll-orderer \
  --root-dir $ROOT_DIR \
  --domain example.com \
  --ca-port 8054 --tlsca-port 8154 \
  --ca-name ca-orderer \
  --tlsca-name tlsca-orderer
