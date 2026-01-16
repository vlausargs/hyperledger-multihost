# Quick Start Guide - Chaincode Client for Laptop 1

Get started with the Fabric chaincode client in 5 minutes.

## Prerequisites

- ✅ Fabric peer binary installed and in PATH
- ✅ Fabric network running (peer and orderer containers)
- ✅ Go 1.22+ installed
- ✅ Chaincode `basic` installed and committed on `mychannel`

## Quick Setup

### 1. Build the Client

```bash
cd /home/valos/workspace/hyperledger/hyperledger-multihost/chaincode-client
go build -o chaincode-client main.go
chmod +x chaincode-client
```

### 2. Verify Network is Ready

```bash
# Check peer is running
docker ps | grep peer0.org1.example.com

# Check peer has joined channel
peer channel list

# Check chaincode is committed
peer lifecycle chaincode querycommitted -C mychannel
```

If chaincode is not committed, follow the [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for chaincode deployment.

## Basic Usage

### Create Your First Asset

```bash
./chaincode-client create asset001 Alice 1000
```

### Read an Asset

```bash
./chaincode-client read asset001
```

### List All Assets

```bash
./chaincode-client list
```

### Update Asset Owner

```bash
./chaincode-client update-owner asset001 Bob
```

### Update Asset Value

```bash
./chaincode-client update-value asset001 2500
```

### Delete an Asset

```bash
./chaincode-client delete asset001
```

### Check if Asset Exists

```bash
./chaincode-client exists asset001
```

## Command Reference

| Command | Syntax | Description |
|---------|--------|-------------|
| `create` | `./chaincode-client create <id> <owner> <value>` | Create new asset |
| `read` | `./chaincode-client read <id>` | Read asset by ID |
| `update-owner` | `./chaincode-client update-owner <id> <newOwner>` | Transfer ownership |
| `update-value` | `./chaincode-client update-value <id> <newValue>` | Update value |
| `delete` | `./chaincode-client delete <id>` | Delete asset |
| `exists` | `./chaincode-client exists <id>` | Check existence |
| `list` | `./chaincode-client list` | List all assets |

## Quick Test Workflow

```bash
# 1. Create an asset
./chaincode-client create test_asset Alice 500

# 2. Read it back
./chaincode-client read test_asset

# 3. Update owner
./chaincode-client update-owner test_asset Bob

# 4. Update value
./chaincode-client update-value test_asset 1000

# 5. List all assets
./chaincode-client list

# 6. Clean up
./chaincode-client delete test_asset
```

## Troubleshooting

### "peer: command not found"
```bash
# Add Fabric binaries to PATH
export PATH=$PATH:$HOME/fabric/bin
```

### "failed to connect to peer"
```bash
# Check peer container
docker ps | grep peer0.org1.example.com

# Check peer logs
docker logs peer0.org1.example.com --tail 20
```

### "chaincode basic not found"
```bash
# Check committed chaincodes
peer lifecycle chaincode querycommitted -C mychannel

# If not found, deploy chaincode first (see DEPLOYMENT_GUIDE.md)
```

### "Access denied"
```bash
# Re-enroll admin
cd /home/valos/workspace/hyperledger/hyperledger-multihost
./scripts/02a-enroll-org1.sh
```

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Check [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for complete network setup
- Review [CHANGES.md](CHANGES.md) for information about the CLI wrapper architecture

## Need Help?

1. Check the logs: `docker logs peer0.org1.example.com`
2. Verify configuration in `main.go`
3. Consult Hyperledger Fabric documentation
4. Ask in the Fabric community chat

---

**Ready to go!** The client is now built and ready to use. Start creating assets! 🚀