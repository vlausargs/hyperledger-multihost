#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-env.sh"

peer_env_org1

# Increase delivery client timeout to prevent timeout when fetching blocks from orderer
export CORE_PEER_DELIVERYCLIENT_TIMEOUT=300s
export CORE_PEER_CLIENT_TIMEOUT=300s

echo "==> Check commit readiness (Org2 context)"
peer lifecycle chaincode checkcommitreadiness \
  --channelID "${CHANNEL_NAME}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --sequence "${CC_SEQUENCE}" \
  --signature-policy "${CC_ENDORSEMENT_POLICY}" \
  --output json

echo "==> Commit chaincode definition"
peer lifecycle chaincode commit \
  -o "orderer.${DOMAIN}:${ORDERER_PORT}" \
  --channelID "${CHANNEL_NAME}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --sequence "${CC_SEQUENCE}" \
  --signature-policy "${CC_ENDORSEMENT_POLICY}" \
  --peerAddresses "peer0.org1.${DOMAIN}:${ORG1_PEER_PORT}" \
  --tlsRootCertFiles "${ROOT_DIR}/organizations/peerOrganizations/org1.${DOMAIN}/peers/peer0.org1.${DOMAIN}/tls/ca.crt" \
  --peerAddresses "peer0.org2.${DOMAIN}:${ORG2_PEER_PORT}" \
  --tlsRootCertFiles "${ROOT_DIR}/organizations/peerOrganizations/org2.${DOMAIN}/peers/peer0.org2.${DOMAIN}/tls/ca.crt" \
  --peerAddresses "peer0.org3.${DOMAIN}:${ORG3_PEER_PORT}" \
  --tlsRootCertFiles "${ROOT_DIR}/organizations/peerOrganizations/org3.${DOMAIN}/peers/peer0.org3.${DOMAIN}/tls/ca.crt" \
  --tls --cafile "${ORDERER_CA}"

echo "==> Query committed"
peer lifecycle chaincode querycommitted \
  --channelID "${CHANNEL_NAME}" \
  --name "${CC_NAME}"
