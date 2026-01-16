#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

echo "==============================================="
echo "Restarting Peer Container on Laptop1"
echo "==============================================="
echo ""
echo "This script will restart the peer container to ensure"
echo "the DNS configuration (extra_hosts) is properly applied."
echo ""

# Function to check if a container is running
container_running() {
  docker ps --format '{{.Names}}' | grep -q "^${1}$"
}

# Function to stop a container
stop_container() {
  local container_name="$1"
  if container_running "${container_name}"; then
    echo "Stopping ${container_name}..."
    docker stop "${container_name}"
    echo "✅ Stopped ${container_name}"
  else
    echo "⚠️  Container ${container_name} is not running"
  fi
}

# Function to remove a container
remove_container() {
  local container_name="$1"
  if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    echo "Removing ${container_name}..."
    docker rm "${container_name}"
    echo "✅ Removed ${container_name}"
  fi
}

# Function to start the peer container
start_peer() {
  local compose_file="$1"
  local peer_name="$2"

  echo ""
  echo "Starting ${peer_name}..."
  docker-compose -f "${compose_file}" up -d

  if [ $? -eq 0 ]; then
    echo "✅ Started ${peer_name}"

    # Wait for container to be fully started
    echo "Waiting for ${peer_name} to be ready..."
    sleep 3

    # Verify it's running
    if container_running "${peer_name}"; then
      echo "✅ ${peer_name} is running"
    else
      echo "❌ ${peer_name} failed to start"
      return 1
    fi
  else
    echo "❌ Failed to start ${peer_name}"
    return 1
  fi
}

# Check if required file exists
if [ ! -f "${ROOT_DIR}/compose/docker-compose.laptop1-org1-peer.yaml" ]; then
  echo "❌ Error: docker-compose.laptop1-org1-peer.yaml not found"
  exit 1
fi

# Stop existing container
echo "==============================================="
echo "Step 1: Stopping Existing Peer Container"
echo "==============================================="
echo ""

stop_container "peer0.org1.example.com"

echo ""
echo "Waiting for container to fully stop..."
sleep 2

# Remove container to ensure fresh start
echo ""
echo "==============================================="
echo "Step 2: Removing Old Container"
echo "==============================================="
echo ""

remove_container "peer0.org1.example.com"

sleep 2

# Start container with updated configuration
echo ""
echo "==============================================="
echo "Step 3: Starting Container with Updated Config"
echo "==============================================="
echo ""

cd "${ROOT_DIR}/compose"

# Start Org1 peer
start_peer "docker-compose.laptop1-org1-peer.yaml" "peer0.org1.example.com"

echo ""
echo "==============================================="
echo "Step 4: Verifying DNS Configuration"
echo "==============================================="
echo ""

# Check if orderer.example.com is in the extra_hosts of the container
echo "Checking extra_hosts in peer0.org1.example.com..."
if docker exec peer0.org1.example.com grep -q "orderer.example.com" /etc/hosts 2>/dev/null; then
  echo "✅ orderer.example.com found in /etc/hosts"
  docker exec peer0.org1.example.com grep "orderer.example.com" /etc/hosts | sed 's/^/   /'
else
  echo "❌ orderer.example.com NOT found in /etc/hosts"
fi

echo ""
echo "Verifying all Fabric host entries..."
echo "Host entries in peer0.org1.example.com /etc/hosts:"
docker exec peer0.org1.example.com grep -E "orderer|peer0.org" /etc/hosts | sed 's/^/   /'

echo ""
echo "==============================================="
echo "Step 5: Verifying Container Connectivity"
echo "==============================================="
echo ""

# Test DNS resolution from within container
echo "Testing DNS resolution from peer0.org1.example.com..."
if docker exec peer0.org1.example.com nslookup orderer.example.com >/dev/null 2>&1; then
  echo "✅ orderer.example.com resolves successfully"
else
  echo "⚠️  orderer.example.com DNS resolution failed (may be okay if using /etc/hosts)"
fi

echo ""
echo "Testing TCP connection to orderer from peer0.org1.example.com..."
if docker exec peer0.org1.example.com timeout 3 nc -zv orderer.example.com 7050 2>&1 | grep -q "succeeded"; then
  echo "✅ Can connect to orderer.example.com:7050"
  echo "   Orderer is on laptop2 at ${LAPTOP2_IP}"
else
  echo "❌ Cannot connect to orderer.example.com:7050"
  echo "   Make sure:"
  echo "   - Orderer is running on laptop2"
  echo "   - Network connectivity exists between laptop1 (${LAPTOP1_IP}) and laptop2 (${LAPTOP2_IP})"
  echo "   - Firewall allows port 7050"
fi

# Test connection to local peers
echo ""
echo "Testing TCP connection to local peer..."
if docker exec peer0.org1.example.com timeout 3 nc -zv localhost ${ORG1_PEER_PORT} 2>&1 | grep -q "succeeded"; then
  echo "✅ Can connect to localhost:${ORG1_PEER_PORT}"
else
  echo "❌ Cannot connect to localhost:${ORG1_PEER_PORT}"
fi

# Final status
echo ""
echo "==============================================="
echo "Final Status"
echo "==============================================="
echo ""

echo "Running containers:"
docker ps --filter "name=peer0.org1" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "==============================================="
echo "✅ Peer Restart Complete"
echo "==============================================="
echo ""
echo "The peer container has been restarted with the"
echo "updated DNS configuration. It should now be able to"
echo "resolve and connect to the orderer and other peers."
echo ""
echo "If you still experience issues, run the diagnostic script:"
echo "  ./scripts-v2/diagnose-peer.sh org1"
echo ""
echo "Next steps:"
echo "1. Verify peer has joined the channel:"
echo "   peer channel list"
echo ""
echo "2. If not joined, run:"
echo "   ./scripts-v2/laptop1/09-join-channel-org1-peer.sh"
echo ""
