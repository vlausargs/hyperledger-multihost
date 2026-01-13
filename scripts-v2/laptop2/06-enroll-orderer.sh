#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

CA_PORT="${ORDERER_CA_PORT}"
TLSCA_PORT="${ORDERER_TLSCA_PORT}"
CA_NAME="ca-orderer"
TLSCA_NAME="tlsca-orderer"

CA_TLS_CERT="${ROOT_DIR}/organizations/fabric-ca/orderer/ca/tls-cert.pem"
TLSCA_TLS_CERT="${ROOT_DIR}/organizations/fabric-ca/orderer/tlsca/tls-cert.pem"

ORDERER_FQDN="orderer.${DOMAIN}"

# Base orderer org home (CA-side client home) and a dedicated TLSCA client home
ORG_HOME="${ROOT_DIR}/organizations/ordererOrganizations/${DOMAIN}"
TLSCA_CLIENT_HOME="${ORG_HOME}/.tlsca-client"

mkdir -p "${ORG_HOME}"
mkdir -p "${TLSCA_CLIENT_HOME}"

export FABRIC_CA_CLIENT_HOME="${ORG_HOME}"

# -----------------------------
# Helpers
# -----------------------------
register_idempotent() {
  # Usage: register_idempotent <caname> <tls_cert> <name> <secret> <type>
  local CANAME="$1"
  local TLS_CERT="$2"
  local NAME="$3"
  local SECRET="$4"
  local TYPE="$5"

  set +e
  OUT=$(fabric-ca-client register \
    --caname "${CANAME}" \
    --id.name "${NAME}" \
    --id.secret "${SECRET}" \
    --id.type "${TYPE}" \
    --tls.certfiles "${TLS_CERT}" 2>&1)
  RC=$?
  set -e

  if [ "${RC}" -ne 0 ]; then
    if echo "${OUT}" | grep -qi "already registered"; then
      echo "==> Identity '${NAME}' already registered on ${CANAME}; continuing."
      return 0
    fi
    echo "${OUT}"
    return "${RC}"
  fi

  echo "${OUT}"
}

write_nodeous_config() {
  local CACERT_PATH
  CACERT_PATH="$(ls "${ORG_HOME}/msp/cacerts/"*.pem | head -n 1)"
  local CACERT_BASENAME
  CACERT_BASENAME="$(basename "${CACERT_PATH}")"

  cat > "${ORG_HOME}/msp/config.yaml" <<EOF
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
}

standardize_server_tls() {
  local TLS_DIR="$1"
  cp "${TLS_DIR}/tlscacerts/"* "${TLS_DIR}/ca.crt"
  cp "${TLS_DIR}/signcerts/"* "${TLS_DIR}/server.crt"
  cp "${TLS_DIR}/keystore/"* "${TLS_DIR}/server.key"
}

standardize_client_tls() {
  local TLS_DIR="$1"
  cp "${TLS_DIR}/tlscacerts/"* "${TLS_DIR}/ca.crt"
  cp "${TLS_DIR}/signcerts/"* "${TLS_DIR}/client.crt"
  cp "${TLS_DIR}/keystore/"* "${TLS_DIR}/client.key"
}

# -----------------------------
# CA: enroll admin + register + enroll orderer MSP
# -----------------------------
echo "==> Enroll Orderer CA admin (${CA_NAME})"
fabric-ca-client enroll \
  -u "https://admin:adminpw@localhost:${CA_PORT}" \
  --caname "${CA_NAME}" \
  --tls.certfiles "${CA_TLS_CERT}"

echo "==> Write NodeOUs config.yaml"
write_nodeous_config

echo "==> Register orderer + orderer admin on CA (idempotent)"
register_idempotent "${CA_NAME}" "${CA_TLS_CERT}" "orderer"      "ordererpw"      "orderer"
register_idempotent "${CA_NAME}" "${CA_TLS_CERT}" "ordereradmin" "ordereradminpw" "admin"

echo "==> Enroll orderer MSP"
fabric-ca-client enroll \
  -u "https://orderer:ordererpw@localhost:${CA_PORT}" \
  --caname "${CA_NAME}" \
  -M "${ORG_HOME}/orderers/${ORDERER_FQDN}/msp" \
  --csr.hosts "${ORDERER_FQDN}" \
  --tls.certfiles "${CA_TLS_CERT}"

cp "${ORG_HOME}/msp/config.yaml" "${ORG_HOME}/orderers/${ORDERER_FQDN}/msp/config.yaml"

# -----------------------------
# TLSCA: enroll admin + register (IMPORTANT: separate FABRIC_CA_CLIENT_HOME)
# -----------------------------
export FABRIC_CA_CLIENT_HOME="${TLSCA_CLIENT_HOME}"

echo "==> Enroll TLSCA admin (${TLSCA_NAME})"
fabric-ca-client enroll \
  -u "https://admin:adminpw@localhost:${TLSCA_PORT}" \
  --caname "${TLSCA_NAME}" \
  --tls.certfiles "${TLSCA_TLS_CERT}"

echo "==> Register orderer + admin on TLSCA (idempotent)"
register_idempotent "${TLSCA_NAME}" "${TLSCA_TLS_CERT}" "orderer"      "ordererpw"      "orderer"
register_idempotent "${TLSCA_NAME}" "${TLSCA_TLS_CERT}" "ordereradmin" "ordereradminpw" "admin"

# -----------------------------
# Enroll orderer TLS (write into ORG_HOME) - switch back
# -----------------------------
export FABRIC_CA_CLIENT_HOME="${ORG_HOME}"

echo "==> Enroll orderer TLS"
fabric-ca-client enroll \
  -u "https://orderer:ordererpw@localhost:${TLSCA_PORT}" \
  --caname "${TLSCA_NAME}" \
  -M "${ORG_HOME}/orderers/${ORDERER_FQDN}/tls" \
  --enrollment.profile tls \
  --csr.hosts "${ORDERER_FQDN}" --csr.hosts localhost \
  --tls.certfiles "${TLSCA_TLS_CERT}"

echo "==> Standardize orderer TLS filenames"
ORDERER_TLS_DIR="${ORG_HOME}/orderers/${ORDERER_FQDN}/tls"
standardize_server_tls "${ORDERER_TLS_DIR}"

mkdir -p "${ORG_HOME}/msp/tlscacerts"
cp "${ORDERER_TLS_DIR}/ca.crt" "${ORG_HOME}/msp/tlscacerts/ca.crt"

# -----------------------------
# Enroll Orderer Admin MSP (CA)
# -----------------------------
echo "==> Enroll Orderer Admin MSP"
fabric-ca-client enroll \
  -u "https://ordereradmin:ordereradminpw@localhost:${CA_PORT}" \
  --caname "${CA_NAME}" \
  -M "${ORG_HOME}/users/Admin@${DOMAIN}/msp" \
  --tls.certfiles "${CA_TLS_CERT}"

cp "${ORG_HOME}/msp/config.yaml" "${ORG_HOME}/users/Admin@${DOMAIN}/msp/config.yaml"

# -----------------------------
# Enroll Orderer Admin TLS (for osnadmin mTLS)
# NOTE: This is an enrollment to TLSCA. It does NOT require TLSCA register if CA has registrar attrs
# but we already registered ordereradmin on TLSCA above for consistency/idempotency.
# -----------------------------
echo "==> Enroll Orderer Admin TLS (for osnadmin mTLS)"
fabric-ca-client enroll \
  -u "https://ordereradmin:ordereradminpw@localhost:${TLSCA_PORT}" \
  --caname "${TLSCA_NAME}" \
  -M "${ORG_HOME}/users/Admin@${DOMAIN}/tls" \
  --enrollment.profile tls \
  --csr.hosts "Admin@${DOMAIN}" --csr.hosts localhost \
  --tls.certfiles "${TLSCA_TLS_CERT}"

echo "==> Standardize Orderer Admin TLS filenames"
ADMIN_TLS_DIR="${ORG_HOME}/users/Admin@${DOMAIN}/tls"
standardize_client_tls "${ADMIN_TLS_DIR}"

echo "Orderer enrollment complete."

echo "==> Quick checks"
ls -lah "${ORDERER_TLS_DIR}"
ls -lah "${ADMIN_TLS_DIR}"
