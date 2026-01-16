# Hyperledger Fabric Timeout Troubleshooting Guide

This guide explains and helps resolve timeout issues that occur when working with Hyperledger Fabric in a multi-host setup across different network segments.

## Problem Description

When running chaincode lifecycle operations (approve, commit, etc.) in a multi-host Fabric network, you may encounter timeout errors like:

```
Error: error receiving from deliver filtered at peer0.org2.example.com:9051: 
rpc error: code = DeadlineExceeded desc = context finished before block retrieved: 
context deadline exceeded
```

## Common Symptoms

1. **Chaincode Approval Timeouts**: `peer lifecycle chaincode approveformyorg` fails after waiting
2. **Commit Readiness Check Timeouts**: `peer lifecycle chaincode checkcommitreadiness` hangs
3. **Channel Query Timeouts**: `peer channel fetch` or `peer channel getinfo` fails
4. **Long Running Operations**: Commands that work locally timeout across network boundaries

## Root Causes

### 1. Default Timeout Settings Too Short
Fabric's peer CLI has default delivery timeouts (typically 5-10 seconds) designed for local development. In multi-host setups, network latency can exceed these defaults.

### 2. Network Latency
Different network segments, VPNs, or subnets introduce latency that exceeds timeout thresholds.

### 3. Ledger Synchronization Delays
When peers need to fetch multiple blocks to synchronize with the channel state, the cumulative time exceeds the timeout.

### 4. Block Retrieval Bottlenecks
The orderer may take longer to deliver blocks due to:
- Large block sizes
- Network congestion
- Orderer resource constraints

## Immediate Solutions

### Solution 1: Increase Delivery Client Timeout (Recommended)

Add the following environment variables before running peer commands:

```bash
export CORE_PEER_DELIVERYCLIENT_TIMEOUT=300s
export CORE_PEER_CLIENT_TIMEOUT=300s
```

Then run your chaincode commands:
```bash
peer lifecycle chaincode approveformyorg \
  -o "orderer.example.com:7050" \
  --channelID mychannel \
  --name mycc \
  --version 1.0 \
  --package-id <PACKAGE_ID> \
  --sequence 1 \
  --signature-policy "OR('Org1MSP.member','Org2MSP.member','Org3MSP.member')" \
  --tls --cafile /path/to/orderer/ca.crt
```

### Solution 2: Run Diagnostic Script

Use the included diagnostic script to identify issues:

```bash
# For Org2 on laptop2
./scripts-v2/diagnose-peer.sh org2

# For Org3 on laptop2
./scripts-v2/diagnose-peer.sh org3

# For Org1 on laptop1
./scripts-v2/diagnose-peer.sh org1
```

This script checks:
- Container status
- Network connectivity
- DNS resolution
- Channel membership
- Ledger synchronization
- Recent errors in logs
- Installed chaincode

### Solution 3: Verify Network Connectivity

Test TCP connection to orderer:
```bash
# Test connection to orderer
nc -zv orderer.example.com 7050

# Ping orderer host
ping -c 3 orderer.example.com
```

### Solution 4: Check Orderer Status

Verify orderer has blocks to deliver:
```bash
# Check orderer logs
docker logs orderer.example.com --tail 50

# Check if orderer is processing blocks
docker logs orderer.example.com | grep "Writing block"
```

## Long-Term Solutions

### 1. Configure Peer Container Environment Variables

Add timeout settings to your Docker Compose files:

```yaml
services:
  peer0.org2.example.com:
    environment:
      # ... existing settings ...
      - CORE_PEER_DELIVERYCLIENT_TIMEOUT=300s
      - CORE_PEER_CLIENT_TIMEOUT=300s
```

Apply to:
- `compose/docker-compose.laptop2-org2-peer.yaml`
- `compose/docker-compose.laptop2-org3-peer.yaml`
- `compose/docker-compose.laptop1-org1-peer.yaml`

After updating, restart containers:
```bash
docker-compose -f compose/docker-compose.laptop2-org2-peer.yaml down
docker-compose -f compose/docker-compose.laptop2-org2-peer.yaml up -d
```

### 2. Adjust Core YAML Configuration

Modify `config/core.yaml` to increase default timeouts:

```yaml
peer:
  deliveryclient:
    # Time to wait for delivery service to respond
    reconnectTotalTimeThreshold: 300s
    
    # Time to wait for a single block delivery request
    connTimeout: 300s
```

### 3. Optimize Network Configuration

Ensure:
- Firewalls allow ports 7050, 7051, 9051, etc.
- No NAT issues between laptops
- Consistent DNS configuration across all hosts
- Stable network connectivity (avoid WiFi if possible)

## Diagnostic Steps

### Step 1: Check Container Status

```bash
# On laptop2
docker ps | grep -E "orderer|peer0.org2|peer0.org3"

# On laptop1
docker ps | grep peer0.org1
```

All containers should be running.

### Step 2: Verify /etc/hosts Configuration

**On Laptop1 (192.168.7.111):**
```bash
cat /etc/hosts
# Should include:
# 192.168.7.112 orderer.example.com peer0.org2.example.com peer0.org3.example.com
# 192.168.7.111 peer0.org1.example.com
```

**On Laptop2 (192.168.7.112):**
```bash
cat /etc/hosts
# Should include:
# 192.168.7.112 orderer.example.com peer0.org2.example.com peer0.org3.example.com
# 192.168.7.111 peer0.org1.example.com
```

### Step 3: Check Peer Channel Status

```bash
# Set peer environment
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_MSPCONFIGPATH="organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp"
export CORE_PEER_TLS_ROOTCERT_FILE="organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
export CORE_PEER_ADDRESS="peer0.org2.example.com:9051"

# List channels
peer channel list

# Get channel info
peer channel getinfo -c mychannel
```

### Step 4: Check Orderer Logs

```bash
# View recent orderer logs
docker logs orderer.example.com --tail 100

# Look for errors
docker logs orderer.example.com 2>&1 | grep -i error

# Check block creation
docker logs orderer.example.com 2>&1 | grep "Writing block"
```

### Step 5: Check Peer Logs

```bash
# View recent peer logs
docker logs peer0.org2.example.com --tail 100

# Look for timeout errors
docker logs peer0.org2.example.com 2>&1 | grep -i timeout

# Look for delivery errors
docker logs peer0.org2.example.com 2>&1 | grep -i "deliver"
```

## Prevention Tips

1. **Always set timeouts in production environments** - Never rely on default timeouts for multi-host deployments.

2. **Monitor network latency** - Use tools like `ping` and `traceroute` to understand your network characteristics.

3. **Keep peers synchronized** - Regularly check that all peers are at the same block height.

4. **Use consistent hardware** - Similar hardware performance across hosts reduces synchronization issues.

5. **Test operations incrementally** - Test with small transactions before committing to large ones.

6. **Monitor orderer performance** - Ensure the orderer has sufficient resources (CPU, memory, disk I/O).

7. **Configure proper logging** - Set `FABRIC_LOGGING_SPEC=DEBUG` during troubleshooting to get detailed information.

## Updated Scripts

The following scripts have been updated with increased timeout settings:

**Laptop2:**
- `scripts-v2/laptop2/13-cc-approve-org2.sh` - Added 300s timeout
- `scripts-v2/laptop2/14-cc-approve-org3.sh` - Added 300s timeout

**Laptop1:**
- `scripts-v2/laptop1/12-cc-approve-org1.sh` - Added 300s timeout

**Original scripts:**
- `scripts/12-l2-cc-approve-org2.sh` - Added 300s timeout
- `scripts/13-l2-cc-approve-org3.sh` - Added 300s timeout
- `scripts/14-l1-cc-approve-org1.sh` - Added 300s timeout
- `scripts/15-l2-cc-commit.sh` - Added 300s timeout

**Diagnostic tool:**
- `scripts-v2/diagnose-peer.sh` - New diagnostic script

## Common Error Messages and Solutions

### Error: "context deadline exceeded"
**Cause:** Default timeout too short for network latency.
**Solution:** Set `CORE_PEER_DELIVERYCLIENT_TIMEOUT=300s` and `CORE_PEER_CLIENT_TIMEOUT=300s`.

### Error: "connection refused"
**Cause:** Orderer not running or wrong port.
**Solution:** Check orderer container status and verify `ORDERER_PORT` in .env file.

### Error: "no such host"
**Cause:** DNS resolution failure.
**Solution:** Check /etc/hosts configuration on all laptops.

### Error: "certificate signed by unknown authority"
**Cause:** TLS certificate mismatch.
**Solution:** Verify `CORE_PEER_TLS_ROOTCERT_FILE` and `ORDERER_CA` paths are correct.

### Error: "peer is not joined to channel"
**Cause:** Peer hasn't joined the channel.
**Solution:** Run channel join script: `./scripts-v2/laptop2/09-join-channel-org2-peer.sh`

## Getting Help

If issues persist after following this guide:

1. Run the diagnostic script and capture the output
2. Collect relevant logs:
   ```bash
   docker logs orderer.example.com > orderer.log
   docker logs peer0.org2.example.com > peer2.log
   ```
3. Check the Hyperledger Fabric documentation: https://hyperledger-fabric.readthedocs.io/
4. Review the project README for setup instructions

## Quick Reference: Timeout Commands

```bash
# Set timeouts for current session
export CORE_PEER_DELIVERYCLIENT_TIMEOUT=300s
export CORE_PEER_CLIENT_TIMEOUT=300s

# Approve chaincode with increased timeout
peer lifecycle chaincode approveformyorg \
  -o "orderer.example.com:7050" \
  --channelID mychannel \
  --name mycc \
  --version 1.0 \
  --package-id <PKG_ID> \
  --sequence 1 \
  --signature-policy "OR('Org1MSP.member','Org2MSP.member')" \
  --tls --cafile organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

# Commit chaincode with increased timeout
peer lifecycle chaincode commit \
  -o "orderer.example.com:7050" \
  --channelID mychannel \
  --name mycc \
  --version 1.0 \
  --sequence 1 \
  --peerAddresses peer0.org1.example.com:7051 \
  --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --tls --cafile organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
```

## Version Information

This guide is applicable for:
- Hyperledger Fabric 2.5.x LTS
- Multi-host deployment across multiple laptops
- Docker Compose v2
- Fabric CA-based identity management