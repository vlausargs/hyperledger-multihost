#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-env.sh"

ORG=org2
CA_PORT="${ORG2_CA_PORT}"
TLSCA_PORT="${ORG2_TLSCA_PORT}"
CA_NAME="ca-org2"
TLSCA_NAME="tlsca-org2"

CA_TLS_CERT="${ROOT_DIR}/organizations/fabric-ca/org2/ca/tls-cert.pem"
TLSCA_TLS_CERT="${ROOT_DIR}/organizations/fabric-ca/org2/tlsca/tls-cert.pem"

PEER_FQDN="peer0.${ORG}.${DOMAIN}"

# Base org home (CA-side client home) and dedicated TLSCA client home
ORG_HOME="${ROOT_DIR}/organizations/peerOrganizations/${ORG}.${DOMAIN}"
TLSCA_CLIENT_HOME="${ORG_HOME}/.tlsca-client"

mkdir -p "${ORG_HOME}"
mkdir -p "${TLSCA_CLIENT_HOME}"

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
    # Accept "already registered" as success for idempotency
    if echo "${OUT}" | grep -qi "already registered"; then
      echo "==> Identity '${NAME}' already registered on ${CANAME}; continuing."
      return 0
    fi
    echo "${OUT}"
    return "${RC}"
  fi

  # Some versions print prompts / info, keep it visible
  echo "${OUT}"
}

ensure_nodeous_config() {
  # Writes NodeOUs config.yaml under ORG_HOME/msp/config.yaml with correct cacerts filename
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

standardize_tls_filenames() {
  local TLS_DIR="$1"

  # Expect Fabric CA TLS enrollment layout: tlscacerts/, signcerts/, keystore/
  cp "${TLS_DIR}/tlscacerts/"* "${TLS_DIR}/ca.crt"
  cp "${TLS_DIR}/signcerts/"* "${TLS_DIR}/server.crt"
  cp "${TLS_DIR}/keystore/"* "${TLS_DIR}/server.key"
}

# -----------------------------
# CA: enroll admin + register + enroll peer MSP
# -----------------------------
export FABRIC_CA_CLIENT_HOME="${ORG_HOME}"

echo "==> Enroll CA admin (${CA_NAME})"
fabric-ca-client enroll \
  -u "https://admin:adminpw@localhost:${CA_PORT}" \
  --caname "${CA_NAME}" \
  --tls.certfiles "${CA_TLS_CERT}"

echo "==> Write NodeOUs config.yaml"
ensure_nodeous_config

echo "==> Register identities on CA (idempotent)"
register_idempotent "${CA_NAME}" "${CA_TLS_CERT}" "peer0"      "peer0pw"      "peer"
register_idempotent "${CA_NAME}" "${CA_TLS_CERT}" "org2admin"  "org2adminpw"  "admin"
register_idempotent "${CA_NAME}" "${CA_TLS_CERT}" "user1"      "user1pw"      "client"

echo "==> Enroll peer MSP"
fabric-ca-client enroll \
  -u "https://peer0:peer0pw@localhost:${CA_PORT}" \
  --caname "${CA_NAME}" \
  -M "${ORG_HOME}/peers/${PEER_FQDN}/msp" \
  --csr.hosts "${PEER_FQDN}" \
  --tls.certfiles "${CA_TLS_CERT}"

cp "${ORG_HOME}/msp/config.yaml" "${ORG_HOME}/peers/${PEER_FQDN}/msp/config.yaml"

# -----------------------------
# TLSCA: enroll admin + register peer (IMPORTANT: separate FABRIC_CA_CLIENT_HOME)
# -----------------------------
export FABRIC_CA_CLIENT_HOME="${TLSCA_CLIENT_HOME}"

echo "==> Enroll TLSCA admin (${TLSCA_NAME})"
fabric-ca-client enroll \
  -u "https://admin:adminpw@localhost:${TLSCA_PORT}" \
  --caname "${TLSCA_NAME}" \
  --tls.certfiles "${TLSCA_TLS_CERT}"

echo "==> Register peer on TLSCA (idempotent)"
register_idempotent "${TLSCA_NAME}" "${TLSCA_TLS_CERT}" "peer0" "peer0pw" "peer"

# -----------------------------
# Peer TLS enrollment: write certs into ORG_HOME (switch back)
# -----------------------------
export FABRIC_CA_CLIENT_HOME="${ORG_HOME}"

echo "==> Enroll peer TLS"
fabric-ca-client enroll \
  -u "https://peer0:peer0pw@localhost:${TLSCA_PORT}" \
  --caname "${TLSCA_NAME}" \
  -M "${ORG_HOME}/peers/${PEER_FQDN}/tls" \
  --enrollment.profile tls \
  --csr.hosts "${PEER_FQDN}" --csr.hosts localhost \
  --tls.certfiles "${TLSCA_TLS_CERT}"

echo "==> Standardize TLS filenames"
TLS_DIR="${ORG_HOME}/peers/${PEER_FQDN}/tls"
standardize_tls_filenames "${TLS_DIR}"

mkdir -p "${ORG_HOME}/msp/tlscacerts"
cp "${TLS_DIR}/ca.crt" "${ORG_HOME}/msp/tlscacerts/ca.crt"

# -----------------------------
# Org admin MSP
# -----------------------------
echo "==> Enroll Org2 Admin MSP"
fabric-ca-client enroll \
  -u "https://org2admin:org2adminpw@localhost:${CA_PORT}" \
  --caname "${CA_NAME}" \
  -M "${ORG_HOME}/users/Admin@${ORG}.${DOMAIN}/msp" \
  --tls.certfiles "${CA_TLS_CERT}"

cp "${ORG_HOME}/msp/config.yaml" "${ORG_HOME}/users/Admin@${ORG}.${DOMAIN}/msp/config.yaml"

echo "Org2 enrollment complete."

echo "==> Quick check: peer TLS files"
ls -lah "${TLS_DIR}"
