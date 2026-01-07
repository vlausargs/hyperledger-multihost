#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-env.sh"

CA_PORT="${ORDERER_CA_PORT}"
TLSCA_PORT="${ORDERER_TLSCA_PORT}"
CA_NAME="ca-orderer"
TLSCA_NAME="tlsca-orderer"

CA_TLS_CERT="${ROOT_DIR}/organizations/fabric-ca/orderer/ca/tls-cert.pem"
TLSCA_TLS_CERT="${ROOT_DIR}/organizations/fabric-ca/orderer/tlsca/tls-cert.pem"

ORDERER_FQDN="orderer.${DOMAIN}"

mkdir -p "${ROOT_DIR}/organizations/ordererOrganizations/${DOMAIN}"
export FABRIC_CA_CLIENT_HOME="${ROOT_DIR}/organizations/ordererOrganizations/${DOMAIN}"

echo "==> Enroll Orderer CA admin"
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

echo "==> Register orderer + orderer admin"
fabric-ca-client register --caname "${CA_NAME}" --id.name orderer --id.secret ordererpw --id.type orderer --tls.certfiles "${CA_TLS_CERT}"
fabric-ca-client register --caname "${CA_NAME}" --id.name ordereradmin --id.secret ordereradminpw --id.type admin --tls.certfiles "${CA_TLS_CERT}"

echo "==> Enroll orderer MSP"
fabric-ca-client enroll -u "https://orderer:ordererpw@localhost:${CA_PORT}" --caname "${CA_NAME}" \
  -M "${FABRIC_CA_CLIENT_HOME}/orderers/${ORDERER_FQDN}/msp" \
  --csr.hosts "${ORDERER_FQDN}" \
  --tls.certfiles "${CA_TLS_CERT}"

cp "${FABRIC_CA_CLIENT_HOME}/msp/config.yaml" "${FABRIC_CA_CLIENT_HOME}/orderers/${ORDERER_FQDN}/msp/config.yaml"

echo "==> TLSCA admin enroll"
fabric-ca-client enroll -u "https://admin:adminpw@localhost:${TLSCA_PORT}" --caname "${TLSCA_NAME}" --tls.certfiles "${TLSCA_TLS_CERT}"

echo "==> Register orderer + admin on TLSCA"
fabric-ca-client register --caname "${TLSCA_NAME}" --id.name orderer --id.secret ordererpw --id.type orderer --tls.certfiles "${TLSCA_TLS_CERT}"
fabric-ca-client register --caname "${TLSCA_NAME}" --id.name ordereradmin --id.secret ordereradminpw --id.type admin --tls.certfiles "${TLSCA_TLS_CERT}"

echo "==> Enroll orderer TLS"
fabric-ca-client enroll -u "https://orderer:ordererpw@localhost:${TLSCA_PORT}" --caname "${TLSCA_NAME}" \
  -M "${FABRIC_CA_CLIENT_HOME}/orderers/${ORDERER_FQDN}/tls" \
  --enrollment.profile tls \
  --csr.hosts "${ORDERER_FQDN}" --csr.hosts localhost \
  --tls.certfiles "${TLSCA_TLS_CERT}"

TLS_DIR="${FABRIC_CA_CLIENT_HOME}/orderers/${ORDERER_FQDN}/tls"
cp "${TLS_DIR}/tlscacerts/"* "${TLS_DIR}/ca.crt"
cp "${TLS_DIR}/signcerts/"* "${TLS_DIR}/server.crt"
cp "${TLS_DIR}/keystore/"* "${TLS_DIR}/server.key"

mkdir -p "${FABRIC_CA_CLIENT_HOME}/msp/tlscacerts"
cp "${TLS_DIR}/ca.crt" "${FABRIC_CA_CLIENT_HOME}/msp/tlscacerts/ca.crt"

echo "==> Enroll Orderer Admin MSP"
fabric-ca-client enroll -u "https://ordereradmin:ordereradminpw@localhost:${CA_PORT}" --caname "${CA_NAME}" \
  -M "${FABRIC_CA_CLIENT_HOME}/users/Admin@${DOMAIN}/msp" \
  --tls.certfiles "${CA_TLS_CERT}"
cp "${FABRIC_CA_CLIENT_HOME}/msp/config.yaml" "${FABRIC_CA_CLIENT_HOME}/users/Admin@${DOMAIN}/msp/config.yaml"

echo "==> Enroll Orderer Admin TLS (for osnadmin mTLS)"
fabric-ca-client enroll -u "https://ordereradmin:ordereradminpw@localhost:${TLSCA_PORT}" --caname "${TLSCA_NAME}" \
  -M "${FABRIC_CA_CLIENT_HOME}/users/Admin@${DOMAIN}/tls" \
  --enrollment.profile tls \
  --csr.hosts "Admin@${DOMAIN}" --csr.hosts localhost \
  --tls.certfiles "${TLSCA_TLS_CERT}"

ADMIN_TLS_DIR="${FABRIC_CA_CLIENT_HOME}/users/Admin@${DOMAIN}/tls"
cp "${ADMIN_TLS_DIR}/tlscacerts/"* "${ADMIN_TLS_DIR}/ca.crt"
cp "${ADMIN_TLS_DIR}/signcerts/"* "${ADMIN_TLS_DIR}/client.crt"
cp "${ADMIN_TLS_DIR}/keystore/"* "${ADMIN_TLS_DIR}/client.key"

echo "Orderer enrollment complete."
