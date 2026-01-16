# 🚨 DNS Resolution Fix - Action Required Now

## The Problem

Your `peer lifecycle chaincode approveformyorg` command is failing with a timeout error. The REAL cause is that your peer containers **cannot resolve** the orderer hostname.

## Evidence from Your Logs

```
WARN [peer.blocksprovider] DeliverBlocks -> Could not connect to ordering service: 
could not dial endpoint 'orderer.example.com:7050': 
dial tcp: lookup orderer.example.com on 192.168.18.1:53: no such host
```

## ✅ Solution - Do This Now

### Step 1: Restart Peer Containers on Laptop2

```bash
cd ~/workspace/myindo/fabric-2pc-3org-template

# This will restart both peer containers with the fixed DNS configuration
./scripts-v2/laptop2/restart-peers.sh
```

### Step 2: Restart Peer Container on Laptop1

```bash
cd ~/workspace/myindo/fabric-2pc-3org-template

# This will restart the peer container with verified DNS configuration
./scripts-v2/laptop1/restart-peer.sh
```

### Step 3: Verify the Fix

```bash
# On laptop2 - check if orderer is resolvable
docker exec peer0.org2.example.com cat /etc/hosts | grep orderer.example.com

# Should see: 192.168.7.112 orderer.example.com

# Test connection to orderer
docker exec peer0.org2.example.com nc -zv orderer.example.com 7050

# Should see: Connection to orderer.example.com 7050 port [tcp/*] succeeded!
```

### Step 4: Run Your Original Command Again

```bash
# Now this should work!
./scripts-v2/laptop2/13-cc-approve-org2.sh
```

## What Was Fixed

The Docker Compose files were missing the orderer entry in the `extra_hosts` section:

**Added to:**
- `compose/docker-compose.laptop2-org2-peer.yaml`
- `compose/docker-compose.laptop2-org3-peer.yaml`

**Entry added:**
```yaml
extra_hosts:
  - "orderer.example.com:${LAPTOP2_IP}"  # ← This was missing!
```

## If It Still Doesn't Work

Run the diagnostic script to identify any remaining issues:

```bash
./scripts-v2/diagnose-peer.sh org2
```

## Need More Details?

See `DNS_FIX_GUIDE.md` for a complete explanation of the issue and solution.

---

**⚡ Quick Summary:**
1. Run `./scripts-v2/laptop2/restart-peers.sh` on laptop2
2. Run `./scripts-v2/laptop1/restart-peer.sh` on laptop1
3. Run your chaincode approval command again
4. Done! 🎉