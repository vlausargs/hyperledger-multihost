#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts-v2/00-env.sh"

echo "==============================================="
echo "Restarting Peer Containers on Laptop2"
echo "==============================================="
echo ""
echo "This script will restart the peer containers to apply"
echo "the updated DNS configuration (extra_hosts)."
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

# Function to start a peer container
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

# Check if required files exist
if [ ! -f "${ROOT_DIR}/compose/docker-compose.laptop2-org2-peer.yaml" ]; then
  echo "❌ Error: docker-compose.laptop2-org2-peer.yaml not found"
  exit 1
fi

if [ ! -f "${ROOT_DIR}/compose/docker-compose.laptop2-org3-peer.yaml" ]; then
  echo "❌ Error: docker-compose.laptop2-org3-peer.yaml not found"
  exit 1
fi

# Stop existing containers
echo "==============================================="
echo "Step 1: Stopping Existing Peer Containers"
echo "==============================================="
echo ""

stop_container "peer0.org2.example.com"
stop_container "peer0.org3.example.com"

echo ""
echo "Waiting for containers to fully stop..."
sleep 2

# Remove containers to ensure fresh start
echo ""
echo "==============================================="
echo "Step 2: Removing Old Containers"
echo "==============================================="
echo ""

remove_container "peer0.org2.example.com"
remove_container "peer0.org3.example.com"

sleep 2

# Start containers with updated configuration
echo ""
echo "==============================================="
echo "Step 3: Starting Containers with Updated Config"
echo "==============================================="
echo ""

cd "${ROOT_DIR}/compose"

# Start Org2 peer
start_peer "docker-compose.laptop2-org2-peer.yaml" "peer0.org2.example.com"

# Start Org3 peer
start_peer "docker-compose.laptop2-org3-peer.yaml" "peer0.org3.example.com"

echo ""
echo "==============================================="
echo "Step 4: Verifying DNS Configuration"
echo "==============================================="
echo ""

# Check if orderer.example.com is in the extra_hosts of the containers
echo "Checking extra_hosts in peer0.org2.example.com..."
if docker exec peer0.org2.example.com grep -q "orderer.example.com" /etc/hosts 2>/dev/null; then
  echo "✅ orderer.example.com found in /etc/hosts"
  docker exec peer0.org2.example.com grep "orderer.example.com" /etc/hosts | sed 's/^/   /'
else
  echo "❌ orderer.example.com NOT found in /etc/hosts"
fi

echo ""
echo "Checking extra_hosts in peer0.org3.example.com..."
if docker exec peer0.org3.example.com grep -q "orderer.example.com" /etc/hosts 2>/dev/null; then
  echo "✅ orderer.example.com found in /etc/hosts"
  docker exec peer0.org3.example.com grep "orderer.example.com" /etc/hosts | sed 's/^/   /'
else
  echo "❌ orderer.example.com NOT found in /etc/hosts"
fi

echo ""
echo "==============================================="
echo "Step 5: Verifying Container Connectivity"
echo "==============================================="
echo ""

# Test DNS resolution from within containers
echo "Testing DNS resolution from peer0.org2.example.com..."
if docker exec peer0.org2.example.com nslookup orderer.example.com >/dev/null 2>&1; then
  echo "✅ orderer.example.com resolves successfully"
else
  echo "⚠️  orderer.example.com DNS resolution failed (may be okay if using /etc/hosts)"
fi

echo ""
echo "Testing TCP connection to orderer from peer0.org2.example.com..."
if docker exec peer0.org2.example.com timeout 3 nc -zv orderer.example.com 7050 2>&1 | grep -q "succeeded"; then
  echo "✅ Can connect to orderer.example.com:7050"
else
  echo "❌ Cannot connect to orderer.example.com:7050"
  echo "   Make sure the orderer is running on laptop2"
fi

# Final status
echo ""
echo "==============================================="
echo "Final Status"
echo "==============================================="
echo ""

echo "Running containers:"
docker ps --filter "name=peer0.org" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "==============================================="
echo "✅ Peer Restart Complete"
echo "==============================================="
echo ""
echo "The peer containers have been restarted with the updated"
echo "DNS configuration. They should now be able to resolve and"
echo "connect to the orderer."
echo ""
echo "If you still experience issues, run the diagnostic script:"
echo "  ./scripts-v2/diagnose-peer.sh org2"
echo "  ./scripts-v2/diagnose-peer.sh org3"
echo ""
