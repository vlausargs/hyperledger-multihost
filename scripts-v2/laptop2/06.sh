#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

./fabric-enroller/fabric-enroller enroll-orderer \
  --root-dir $ROOT_DIR \
  --domain example.com \
  --ca-port 9054 --tlsca-port 9154 \
  --ca-name ca-orderer \
  --tlsca-name tlsca-orderer
