#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

sudo chown $USER:$USER "${ROOT_DIR}/organizations" -R

./fabric-enroller/fabric-enroller enroll-org \
  --root-dir $ROOT_DIR \
  --org org3 --domain example.com \
  --peer peer0 \
  --ca-port  ${ORG3_CA_PORT} \
  --tlsca-port ${ORG3_TLSCA_PORT} \
  --ca-name ca-org3 \
  --tlsca-name tlsca-org3 \
  --ca-admin-user admin \
  --ca-admin-pass adminpw \
  --tlsca-admin-user admin \
  --tlsca-admin-pass adminpw
