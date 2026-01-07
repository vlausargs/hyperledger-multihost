#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-env.sh"

ORG=org3
CA_PORT="${ORG3_CA_PORT}"
TLSCA_PORT="${ORG3_TLSCA_PORT}"
CA_NAME="ca-org3"
TLSCA_NAME="tlsca-org3"

CA_TLS_CERT="${ROOT_DIR}/organizations/fabric-ca/org3/ca/tls-cert.pem"
TLSCA_TLS_CERT="${ROOT_DIR}/organizations/fabric-ca/org3/tlsca/tls-cert.pem"

PEER_FQDN="peer0.${ORG}.${DOMAIN}"

mkdir -p "${ROOT_DIR}/organizations/peerOrganizations/${ORG}.${DOMAIN}"
export FABRIC_CA_CLIENT_HOME="${ROOT_DIR}/organizations/peerOrganizations/${ORG}.${DOMAIN}"

fabric-ca-client enroll -u "https://admin:adminpw@localhost:${CA_PORT}" --caname "${CA_NAME}" --tls.certfiles "${CA_TLS_CERT}"

CACERT_BASENAME="$(basename "$(ls "${FABRIC_CA_CLIENT_HOME}/msp/cacerts/"*.pem | head -n 1)")"
cat > "${FABRIC_CA_CLIENT_HOME}/msp/config.yaml" <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/${CACERT_BASENAME}
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/${CACERT_BASENAME}
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/${CACERT_BASENAME}
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/${CACERT_BASENAME}
    OrganizationalUnitIdentifier: orderer
EOF

fabric-ca-client register --caname "${CA_NAME}" --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles "${CA_TLS_CERT}"
fabric-ca-client register --caname "${CA_NAME}" --id.name org3admin --id.secret org3adminpw --id.type admin --tls.certfiles "${CA_TLS_CERT}"
fabric-ca-client register --caname "${CA_NAME}" --id.name user1 --id.secret user1pw --id.type client --tls.certfiles "${CA_TLS_CERT}"

fabric-ca-client enroll -u "https://peer0:peer0pw@localhost:${CA_PORT}" --caname "${CA_NAME}" \
  -M "${FABRIC_CA_CLIENT_HOME}/peers/${PEER_FQDN}/msp" \
  --csr.hosts "${PEER_FQDN}" \
  --tls.certfiles "${CA_TLS_CERT}"
cp "${FABRIC_CA_CLIENT_HOME}/msp/config.yaml" "${FABRIC_CA_CLIENT_HOME}/peers/${PEER_FQDN}/msp/config.yaml"

fabric-ca-client enroll -u "https://admin:adminpw@localhost:${TLSCA_PORT}" --caname "${TLSCA_NAME}" --tls.certfiles "${TLSCA_TLS_CERT}"
fabric-ca-client register --caname "${TLSCA_NAME}" --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles "${TLSCA_TLS_CERT}"
fabric-ca-client enroll -u "https://peer0:peer0pw@localhost:${TLSCA_PORT}" --caname "${TLSCA_NAME}" \
  -M "${FABRIC_CA_CLIENT_HOME}/peers/${PEER_FQDN}/tls" \
  --enrollment.profile tls \
  --csr.hosts "${PEER_FQDN}" --csr.hosts localhost \
  --tls.certfiles "${TLSCA_TLS_CERT}"

TLS_DIR="${FABRIC_CA_CLIENT_HOME}/peers/${PEER_FQDN}/tls"
cp "${TLS_DIR}/tlscacerts/"* "${TLS_DIR}/ca.crt"
cp "${TLS_DIR}/signcerts/"* "${TLS_DIR}/server.crt"
cp "${TLS_DIR}/keystore/"* "${TLS_DIR}/server.key"

mkdir -p "${FABRIC_CA_CLIENT_HOME}/msp/tlscacerts"
cp "${TLS_DIR}/ca.crt" "${FABRIC_CA_CLIENT_HOME}/msp/tlscacerts/ca.crt"

fabric-ca-client enroll -u "https://org3admin:org3adminpw@localhost:${CA_PORT}" --caname "${CA_NAME}" \
  -M "${FABRIC_CA_CLIENT_HOME}/users/Admin@${ORG}.${DOMAIN}/msp" \
  --tls.certfiles "${CA_TLS_CERT}"
cp "${FABRIC_CA_CLIENT_HOME}/msp/config.yaml" "${FABRIC_CA_CLIENT_HOME}/users/Admin@${ORG}.${DOMAIN}/msp/config.yaml"

echo "Org3 enrollment complete."
