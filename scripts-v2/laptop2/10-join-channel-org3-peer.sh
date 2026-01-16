#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"
peer_env_org3

#check peer msp
echo "==> Checking Peer MSP"


echo "==> org3 peer join channel ${CHANNEL_NAME}"
set +e
peer channel join -b "channel-artifacts/${CHANNEL_NAME}.block"
JOIN_EXIT_CODE=$?
set -e

if [ $JOIN_EXIT_CODE -ne 0 ]; then
  # Check if peer is already joined
  echo "Join failed, checking if peer is already in the channel..."
  if peer channel list 2>/dev/null | grep -q "${CHANNEL_NAME}"; then
    echo "Peer is already joined to channel ${CHANNEL_NAME}"
  else
    echo "Error: Failed to join peer to channel ${CHANNEL_NAME} (exit code: $JOIN_EXIT_CODE)"
    exit 1
  fi
else
  echo "Peer joined to channel ${CHANNEL_NAME}"
fi