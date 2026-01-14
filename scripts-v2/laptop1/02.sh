#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

sudo chown $USER:$USER "${ROOT_DIR}/organizations" -R

./fabric-enroller/fabric-enroller enroll-org \
  --root-dir $ROOT_DIR \
  --org org1 --domain example.com \
  --peer peer0 \
  --ca-port  ${ORG1_CA_PORT} \
  --tlsca-port ${ORG1_TLSCA_PORT} \
  --ca-name ca-org1 \
  --tlsca-name tlsca-org1 \
  --ca-admin-user admin \
  --ca-admin-pass adminpw \
  --tlsca-admin-user admin \
  --tlsca-admin-pass adminpw

# ./fabric-enroller/fabric-enroller enroll-user \
#   --root-dir $ROOT_DIR \
#   --org org1 --domain example.com \
#   --ca-port ${ORG1_CA_PORT} \
#   --ca-name ca-org1 \
#   --user user2 --secret user2pw --type client
