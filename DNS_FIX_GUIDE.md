# DNS Resolution Fix Guide for Hyperledger Fabric Multi-Host Setup

## Problem Description

When running `peer lifecycle chaincode approveformyorg` on laptop2, you encountered this error:

```
Error: error receiving from deliver filtered at peer0.org2.example.com:9051: 
rpc error: code = DeadlineExceeded desc = context finished before block retrieved: 
context deadline exceeded
```

## Root Cause Analysis

The real issue was **NOT a timeout problem** but a **DNS resolution problem**.

### Evidence from Peer Logs

```
WARN [peer.blocksprovider] DeliverBlocks -> Could not connect to ordering service: 
could not dial endpoint 'orderer.example.com:7050': failed to create new connection: 
connection error: desc = "transport: error while dialing: 
dial tcp: lookup orderer.example.com on 192.168.18.1:53: no such host"
```

The peer container was trying to resolve `orderer.example.com` using DNS server `192.168.18.1:53`, but it couldn't find the hostname.

### Configuration Issue

The `extra_hosts` section in the Docker Compose files for laptop2 peers was **missing the orderer entry**:

**❌ BEFORE (Incorrect):**
```yaml
extra_hosts:
  - "peer0.org1.example.com:${LAPTOP1_IP}"
  - "peer0.org2.example.com:${LAPTOP2_IP}"
  - "peer0.org3.example.com:${LAPTOP2_IP}"
  # ❌ Missing: orderer.example.com:${LAPTOP2_IP}
```

**✅ AFTER (Correct):**
```yaml
extra_hosts:
  - "orderer.example.com:${LAPTOP2_IP}"
  - "peer0.org1.example.com:${LAPTOP1_IP}"
  - "peer0.org2.example.com:${LAPTOP2_IP}"
  - "peer0.org3.example.com:${LAPTOP2_IP}"
```

## Files That Were Fixed

### Laptop2 Peer Containers

1. **compose/docker-compose.laptop2-org2-peer.yaml**
   - Added: `orderer.example.com:${LAPTOP2_IP}` to extra_hosts

2. **compose/docker-compose.laptop2-org3-peer.yaml**
   - Added: `orderer.example.com:${LAPTOP2_IP}` to extra_hosts

### Laptop1 Peer Container

3. **compose/docker-compose.laptop1-org1-peer.yaml**
   - Already had the correct configuration ✅

## How to Apply the Fix

### Option 1: Use the Automated Restart Scripts (Recommended)

#### On Laptop2:

```bash
cd ~/workspace/myindo/fabric-2pc-3org-template
./scripts-v2/laptop2/restart-peers.sh
```

This script will:
1. Stop the existing peer containers
2. Remove the old containers
3. Start them with the updated configuration
4. Verify the DNS configuration
5. Test connectivity to the orderer

#### On Laptop1:

```bash
cd ~/workspace/myindo/fabric-2pc-3org-template
./scripts-v2/laptop1/restart-peer.sh
```

### Option 2: Manual Restart

#### On Laptop2:

```bash
# Stop peers
docker stop peer0.org2.example.com peer0.org3.example.com

# Remove containers
docker rm peer0.org2.example.com peer0.org3.example.com

# Start with updated config
cd ~/workspace/myindo/fabric-2pc-3org-template/compose

docker-compose -f docker-compose.laptop2-org2-peer.yaml up -d
docker-compose -f docker-compose.laptop2-org3-peer.yaml up -d
```

#### On Laptop1:

```bash
# Stop peer
docker stop peer0.org1.example.com

# Remove container
docker rm peer0.org1.example.com

# Start with updated config
cd ~/workspace/myindo/fabric-2pc-3org-template/compose

docker-compose -f docker-compose.laptop1-org1-peer.yaml up -d
```

## Verification Steps

After restarting the containers, verify the fix:

### 1. Check /etc/hosts Inside Containers

```bash
# On laptop2
docker exec peer0.org2.example.com cat /etc/hosts | grep orderer.example.com
# Should output: 192.168.7.112 orderer.example.com

docker exec peer0.org3.example.com cat /etc/hosts | grep orderer.example.com
# Should output: 192.168.7.112 orderer.example.com

# On laptop1
docker exec peer0.org1.example.com cat /etc/hosts | grep orderer.example.com
# Should output: 192.168.7.112 orderer.example.com
```

### 2. Test TCP Connection to Orderer

```bash
# From laptop2 peer container
docker exec peer0.org2.example.com nc -zv orderer.example.com 7050
# Should show: Connection to orderer.example.com 7050 port [tcp/*] succeeded!

# From laptop1 peer container
docker exec peer0.org1.example.com nc -zv orderer.example.com 7050
# Should show: Connection to orderer.example.com 7050 port [tcp/*] succeeded!
```

### 3. Run Diagnostic Script

```bash
# On laptop2
./scripts-v2/diagnose-peer.sh org2
./scripts-v2/diagnose-peer.sh org3

# On laptop1
./scripts-v2/diagnose-peer.sh org1
```

### 4. Check Peer Logs

```bash
# Check if peer can now connect to orderer
docker logs peer0.org2.example.com --tail 20 | grep -i "ordering service"
# Should NOT see "Could not connect to ordering service" errors anymore
```

### 5. Test Chaincode Approval

Now try the command that was failing:

```bash
# On laptop2
./scripts-v2/laptop2/13-cc-approve-org2.sh
```

This should now work without timeout errors!

## Why This Issue Occurred

### Understanding Docker Networking

When you use `network_mode: "host"` in Docker Compose, the container shares the host's network namespace. However, **DNS resolution within containers doesn't automatically use the host's /etc/hosts file**.

### The Role of extra_hosts

The `extra_hosts` configuration in Docker Compose adds entries to the container's `/etc/hosts` file. This is essential for:

1. **Name Resolution**: Converting hostnames to IP addresses without using DNS servers
2. **Cross-host Communication**: Allowing containers on different hosts to communicate
3. **Fabric Requirements**: Fabric peers and orderers need to resolve each other's hostnames

### Network Architecture in Your Setup

```
Laptop1 (192.168.7.111):
├── peer0.org1.example.com:7051

Laptop2 (192.168.7.112):
├── orderer.example.com:7050
├── peer0.org2.example.com:9051
└── peer0.org3.example.com:11051
```

Each container needs to know how to resolve **all** hostnames in the network, not just the ones on its own laptop.

## Preventing Future DNS Issues

### 1. Always Check extra_hosts

When creating or modifying Docker Compose files, ensure all Fabric component hostnames are included in `extra_hosts`:

```yaml
extra_hosts:
  - "orderer.example.com:${LAPTOP2_IP}"
  - "peer0.org1.example.com:${LAPTOP1_IP}"
  - "peer0.org2.example.com:${LAPTOP2_IP}"
  - "peer0.org3.example.com:${LAPTOP2_IP}"
```

### 2. Verify Before Deploying

After updating compose files, verify:

```bash
# Check the compose file
cat compose/docker-compose.laptop2-org2-peer.yaml | grep -A 5 "extra_hosts:"

# After starting, verify inside container
docker exec peer0.org2.example.com cat /etc/hosts
```

### 3. Use the Diagnostic Script

The diagnostic script (`scripts-v2/diagnose-peer.sh`) automatically checks DNS resolution and can catch these issues early.

### 4. Monitor Logs

Keep an eye on peer logs for DNS errors:

```bash
docker logs peer0.org2.example.com -f | grep -i "no such host\|could not connect"
```

## Common DNS-Related Error Messages

### Error: "no such host"

**Cause:** Hostname not in /etc/hosts or DNS
**Solution:** Add to extra_hosts in Docker Compose

### Error: "connection refused"

**Cause:** Hostname resolves, but service not running
**Solution:** Check if target container is running and listening on the port

### Error: "timeout" or "context deadline exceeded"

**Cause:** Could be DNS resolution failing (if using DNS) OR actual timeout
**Solution:** 
1. First, check if hostname resolves (use nc or ping)
2. If DNS fails, use extra_hosts
3. If DNS works but still timeouts, increase timeout settings

## Updated Scripts Summary

### Timeout Settings Added (Preventative)

These scripts now include increased timeout settings as a precaution:

- `scripts-v2/laptop2/09-join-channel-org2-peer.sh`
- `scripts-v2/laptop2/10-join-channel-org3-peer.sh`
- `scripts-v2/laptop2/13-cc-approve-org2.sh`
- `scripts-v2/laptop2/14-cc-approve-org3.sh`
- `scripts-v2/laptop1/09-join-channel-org1-peer.sh`
- `scripts-v2/laptop1/12-cc-approve-org1.sh`

### New Diagnostic and Restart Scripts

- `scripts-v2/diagnose-peer.sh` - Comprehensive diagnostic tool
- `scripts-v2/laptop2/restart-peers.sh` - Automated restart script for laptop2
- `scripts-v2/laptop1/restart-peer.sh` - Automated restart script for laptop1

## Quick Troubleshooting Checklist

If you encounter timeout or connection issues:

1. ✅ **Check container status**: `docker ps | grep fabric`
2. ✅ **Check extra_hosts in compose files**: Verify all hostnames are listed
3. ✅ **Check /etc/hosts in containers**: `docker exec <container> cat /etc/hosts`
4. ✅ **Test TCP connectivity**: `docker exec <container> nc -zv <hostname> <port>`
5. ✅ **Check peer logs**: `docker logs <peer-container> --tail 50 | grep -i error`
6. ✅ **Run diagnostic script**: `./scripts-v2/diagnose-peer.sh <org>`
7. ✅ **Verify network connectivity**: `ping <other-laptop-ip>`
8. ✅ **Check firewall settings**: Ensure ports 7050, 7051, 9051, 11051 are open

## Additional Resources

- **TIMEOUT_TROUBLESHOOTING.md**: Comprehensive timeout troubleshooting guide
- **README.md**: Main project documentation
- **Hyperledger Fabric Documentation**: https://hyperledger-fabric.readthedocs.io/

## Summary

The timeout error you experienced was actually a DNS resolution issue. The peer containers on laptop2 couldn't resolve `orderer.example.com` because it wasn't included in the `extra_hosts` configuration. 

**What was fixed:**
- Added `orderer.example.com:${LAPTOP2_IP}` to extra_hosts in:
  - `compose/docker-compose.laptop2-org2-peer.yaml`
  - `compose/docker-compose.laptop2-org3-peer.yaml`

**What to do now:**
1. Restart the peer containers using the automated scripts
2. Verify DNS resolution works
3. Try the chaincode approval command again

The issue should now be resolved! 🎉