#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

set -a
source ./.env
set +a

export FABRIC_CFG_PATH="${ROOT_DIR}/configtx"

# Common paths
export ORDERER_CA="${ROOT_DIR}/organizations/ordererOrganizations/${DOMAIN}/orderers/orderer.${DOMAIN}/tls/ca.crt"

export ORDERER_ADMIN_TLS_CA="${ORDERER_CA}"
export ORDERER_ADMIN_TLS_CLIENT_CERT="${ROOT_DIR}/organizations/ordererOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/tls/client.crt"
export ORDERER_ADMIN_TLS_CLIENT_KEY="${ROOT_DIR}/organizations/ordererOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/tls/client.key"

export CORE_PEER_TLS_ENABLED=true

peer_env_org1() {
  export CORE_PEER_LOCALMSPID="Org1MSP"
  export CORE_PEER_MSPCONFIGPATH="${ROOT_DIR}/organizations/peerOrganizations/org1.${DOMAIN}/users/Admin@org1.${DOMAIN}/msp"
  export CORE_PEER_TLS_ROOTCERT_FILE="${ROOT_DIR}/organizations/peerOrganizations/org1.${DOMAIN}/peers/peer0.org1.${DOMAIN}/tls/ca.crt"
  export CORE_PEER_ADDRESS="peer0.org1.${DOMAIN}:${ORG1_PEER_PORT}"
}

peer_env_org2() {
  export CORE_PEER_LOCALMSPID="Org2MSP"
  export CORE_PEER_MSPCONFIGPATH="${ROOT_DIR}/organizations/peerOrganizations/org2.${DOMAIN}/users/Admin@org2.${DOMAIN}/msp"
  export CORE_PEER_TLS_ROOTCERT_FILE="${ROOT_DIR}/organizations/peerOrganizations/org2.${DOMAIN}/peers/peer0.org2.${DOMAIN}/tls/ca.crt"
  export CORE_PEER_ADDRESS="peer0.org2.${DOMAIN}:${ORG2_PEER_PORT}"
}

peer_env_org3() {
  export CORE_PEER_LOCALMSPID="Org3MSP"
  export CORE_PEER_MSPCONFIGPATH="${ROOT_DIR}/organizations/peerOrganizations/org3.${DOMAIN}/users/Admin@org3.${DOMAIN}/msp"
  export CORE_PEER_TLS_ROOTCERT_FILE="${ROOT_DIR}/organizations/peerOrganizations/org3.${DOMAIN}/peers/peer0.org3.${DOMAIN}/tls/ca.crt"
  export CORE_PEER_ADDRESS="peer0.org3.${DOMAIN}:${ORG3_PEER_PORT}"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1"; exit 1; }
}

# Parse package ID for a label
query_package_id() {
  local label="$1"
  peer lifecycle chaincode queryinstalled 2>/dev/null | \
    sed -n "s/^Package ID: \(.*\), Label: ${label}$/\1/p" | head -n 1
}
