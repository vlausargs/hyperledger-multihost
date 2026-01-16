#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

echo "==============================================="
echo "Fabric Peer Diagnostic Tool"
echo "==============================================="
echo ""

# Function to check if command exists
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}

# Check required commands
echo "🔍 Checking required commands..."
require_cmd docker
require_cmd peer
require_cmd nc
echo "✅ All required commands found"
echo ""

# Check which org to diagnose
if [ "${1:-}" = "org1" ]; then
  peer_env_org1
  ORG_NAME="org1"
elif [ "${1:-}" = "org3" ]; then
  peer_env_org3
  ORG_NAME="org3"
else
  peer_env_org2
  ORG_NAME="org2"
fi

echo "📊 Diagnosing Peer for: ${ORG_NAME}"
echo "   Peer Address: ${CORE_PEER_ADDRESS}"
echo "   MSP ID: ${CORE_PEER_LOCALMSPID}"
echo ""

# Check peer container status
echo "==============================================="
echo "1. Checking Peer Container Status"
echo "==============================================="
PEER_CONTAINER="peer0.${ORG_NAME}.${DOMAIN}"
if docker ps --format '{{.Names}}' | grep -q "^${PEER_CONTAINER}$"; then
  echo "✅ Peer container '${PEER_CONTAINER}' is running"
else
  echo "❌ Peer container '${PEER_CONTAINER}' is NOT running"
  echo "   Checking if it exists but is stopped..."
  if docker ps -a --format '{{.Names}}' | grep -q "^${PEER_CONTAINER}$"; then
    echo "⚠️  Container exists but is stopped. Try: docker start ${PEER_CONTAINER}"
  else
    echo "❌ Container does not exist. Check your Docker Compose setup."
  fi
fi
echo ""

# Check orderer container status
echo "==============================================="
echo "2. Checking Orderer Container Status"
echo "==============================================="
ORDERER_CONTAINER="orderer.${DOMAIN}"
if docker ps --format '{{.Names}}' | grep -q "^${ORDERER_CONTAINER}$"; then
  echo "✅ Orderer container '${ORDERER_CONTAINER}' is running"
else
  echo "❌ Orderer container '${ORDERER_CONTAINER}' is NOT running"
fi
echo ""

# Check network connectivity to orderer
echo "==============================================="
echo "3. Checking Network Connectivity to Orderer"
echo "==============================================="
ORDERER_HOST="orderer.${DOMAIN}"
ORDERER_PORT="${ORDERER_PORT}"

echo "   Testing TCP connection to ${ORDERER_HOST}:${ORDERER_PORT}..."
if timeout 5 nc -zv "${ORDERER_HOST}" "${ORDERER_PORT}" 2>&1 | grep -q "succeeded"; then
  echo "✅ Network connectivity to orderer is OK"
else
  echo "❌ Cannot connect to orderer at ${ORDERER_HOST}:${ORDERER_PORT}"
  echo "   Checking if host is reachable via ping..."
  if ping -c 1 "${ORDERER_HOST}" >/dev/null 2>&1; then
    echo "✅ Host is reachable, but port ${ORDERER_PORT} may be blocked or not listening"
  else
    echo "❌ Host ${ORDERER_HOST} is NOT reachable"
    echo "   Check /etc/hosts entry for ${ORDERER_HOST}"
  fi
fi
echo ""

# Check DNS resolution
echo "==============================================="
echo "4. Checking DNS Resolution"
echo "==============================================="
echo "   Checking /etc/hosts entries..."
if grep -q "${ORDERER_HOST}" /etc/hosts; then
  echo "✅ Found /etc/hosts entry for ${ORDERER_HOST}:"
  grep "${ORDERER_HOST}" /etc/hosts | sed 's/^/   /'
else
  echo "❌ No /etc/hosts entry found for ${ORDERER_HOST}"
fi

if grep -q "${CORE_PEER_ADDRESS%:*}" /etc/hosts; then
  echo "✅ Found /etc/hosts entry for ${CORE_PEER_ADDRESS%:*}:"
  grep "${CORE_PEER_ADDRESS%:*}" /etc/hosts | sed 's/^/   /'
else
  echo "❌ No /etc/hosts entry found for ${CORE_PEER_ADDRESS%:*}"
fi
echo ""

# Check peer channel list
echo "==============================================="
echo "5. Checking Peer Channel Membership"
echo "==============================================="
echo "   Listing channels peer has joined..."
if peer channel list 2>/dev/null; then
  if peer channel list 2>/dev/null | grep -q "${CHANNEL_NAME}"; then
    echo "✅ Peer is joined to channel '${CHANNEL_NAME}'"
  else
    echo "⚠️  Peer is NOT joined to channel '${CHANNEL_NAME}'"
    echo "   Peer is only joined to these channels:"
    peer channel list 2>/dev/null
  fi
else
  echo "❌ Failed to query channel list. Check peer logs:"
  echo "   docker logs -n 50 ${PEER_CONTAINER}"
fi
echo ""

# Check peer height vs orderer height
echo "==============================================="
echo "6. Checking Ledger Synchronization"
echo "==============================================="
echo "   Fetching latest block from channel..."
set +e
LATEST_BLOCK=$(peer channel fetch newest -c "${CHANNEL_NAME}" 2>&1)
FETCH_EXIT_CODE=$?
set -e

if [ $FETCH_EXIT_CODE -eq 0 ]; then
  BLOCK_FILE=$(ls -t "${CHANNEL_NAME}_newest.block" 2>/dev/null | head -n1)
  if [ -n "${BLOCK_FILE}" ]; then
    echo "✅ Successfully fetched latest block"
    rm -f "${BLOCK_FILE}"
  fi

  # Try to get block info
  echo "   Querying current block height..."
  BLOCK_HEIGHT=$(peer channel getinfo -c "${CHANNEL_NAME}" 2>/dev/null | grep -o 'height:[0-9]*' | cut -d: -f2)
  if [ -n "${BLOCK_HEIGHT}" ]; then
    echo "✅ Current block height: ${BLOCK_HEIGHT}"
    if [ "${BLOCK_HEIGHT}" -lt 2 ]; then
      echo "⚠️  Block height seems low. Channel may not be fully initialized."
    fi
  else
    echo "⚠️  Could not determine block height"
  fi
else
  echo "❌ Failed to fetch block from orderer"
  echo "   Error output:"
  echo "${LATEST_BLOCK}" | sed 's/^/   /'
  echo ""
  echo "   This may indicate:"
  echo "   - Peer is not joined to the channel"
  echo "   - Network connectivity issues to orderer"
  echo "   - Orderer is not running or has no blocks"
  echo "   - TLS certificate issues"
fi
echo ""

# Check peer logs for errors
echo "==============================================="
echo "7. Checking Peer Logs for Errors"
echo "==============================================="
echo "   Looking for recent errors in peer logs..."
ERROR_COUNT=$(docker logs --tail 100 "${PEER_CONTAINER}" 2>&1 | grep -i "error" | wc -l)
if [ "${ERROR_COUNT}" -gt 0 ]; then
  echo "⚠️  Found ${ERROR_COUNT} error(s) in recent logs:"
  docker logs --tail 100 "${PEER_CONTAINER}" 2>&1 | grep -i "error" | head -n 5 | sed 's/^/   /'
else
  echo "✅ No recent errors found in peer logs"
fi
echo ""

# Check installed chaincode
echo "==============================================="
echo "8. Checking Installed Chaincode"
echo "==============================================="
echo "   Querying installed chaincode..."
set +e
CC_OUTPUT=$(peer lifecycle chaincode queryinstalled 2>&1)
CC_EXIT_CODE=$?
set -e

if [ $CC_EXIT_CODE -eq 0 ]; then
  echo "✅ Successfully queried installed chaincode:"
  echo "${CC_OUTPUT}" | grep "Package ID" | sed 's/^/   /'
else
  echo "❌ Failed to query installed chaincode"
  echo "   Error:"
  echo "${CC_OUTPUT}" | sed 's/^/   /'
fi
echo ""

# Summary and recommendations
echo "==============================================="
echo "DIAGNOSTIC SUMMARY"
echo "==============================================="
echo ""
echo "If you're experiencing timeout errors, try:"
echo "1. Ensure all containers are running"
echo "2. Check /etc/hosts entries on ALL laptops"
echo "3. Verify network connectivity between laptops"
echo "4. Check firewall settings on both laptops"
echo "5. Ensure orderer has blocks to deliver"
echo ""
echo "To increase timeout for peer commands, add these environment variables:"
echo "   export CORE_PEER_DELIVERYCLIENT_TIMEOUT=300s"
echo "   export CORE_PEER_CLIENT_TIMEOUT=300s"
echo ""
echo "For more detailed logs:"
echo "   docker logs -f ${PEER_CONTAINER}"
echo "   docker logs -f ${ORDERER_CONTAINER}"
echo ""
