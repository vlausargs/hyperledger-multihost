#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

./fabric-enroller/fabric-enroller enroll-org \
  --root-dir $ROOT_DIR \
  --org org2 --domain example.com \
  --peer peer0 \
  --ca-port  ${ORG2_CA_PORT} \
  --tlsca-port ${ORG2_TLSCA_PORT} \
  --ca-name ca-org2 \
  --tlsca-name tlsca-org2 \
  --ca-admin-user admin \
  --ca-admin-pass adminpw \
  --tlsca-admin-user admin \
  --tlsca-admin-pass adminpw
