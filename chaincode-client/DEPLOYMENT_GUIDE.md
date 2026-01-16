# Chaincode Client Deployment Guide for Laptop 1

This guide provides step-by-step instructions for deploying and using the chaincode client on Laptop 1 (Org1) to interact with the Hyperledger Fabric network.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Network Setup](#network-setup)
3. [Building the Client](#building-the-client)
4. [Chaincode Deployment](#chaincode-deployment)
5. [Using the Client](#using-the-client)
6. [Testing and Verification](#testing-and-verification)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Configuration](#advanced-configuration)

---

## Prerequisites

### 1. System Requirements

- **Operating System**: Linux (tested on Ubuntu/Debian)
- **Docker**: Version 20.10+ with Docker Compose v2
- **Go**: Version 1.22 or higher
- **RAM**: Minimum 4GB (8GB recommended)
- **Disk Space**: 10GB free

### 2. Required Software

#### Install Docker and Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose v2
sudo apt-get update
sudo apt-get install docker-compose-plugin
```

#### Install Fabric Binaries

```bash
# Download Fabric binaries
curl -sSL https://bit.ly/2ysbOFE | bash -s

# Add to PATH
export PATH=$PATH:$HOME/fabric/bin
echo 'export PATH=$PATH:$HOME/fabric/bin' >> ~/.bashrc
source ~/.bashrc

# Verify installation
peer version
```

#### Install Fabric CA Client

```bash
# Download Fabric CA client
curl -sSL https://bit.ly/2ysbOFE | bash -s -- -c

# Add to PATH
export PATH=$PATH:$HOME/fabric-ca-client/bin
echo 'export PATH=$PATH:$HOME/fabric-ca-client/bin' >> ~/.bashrc
source ~/.bashrc
```

### 3. Network Configuration

#### Configure `/etc/hosts` on Both Laptops

Add the following entries to `/etc/hosts` on **BOTH** laptop 1 and laptop 2:

```bash
# Edit hosts file
sudo nano /etc/hosts

# Add these lines:
192.168.7.111 peer0.org1.example.com
192.168.7.112 orderer.example.com peer0.org2.example.com peer0.org3.example.com
```

#### Verify Network Connectivity

```bash
# From Laptop 1, ping Laptop 2
ping 192.168.7.112

# Test DNS resolution
ping peer0.org2.example.com
ping orderer.example.com
```

### 4. Firewall Configuration

Ensure required ports are open:

```bash
# Allow Docker communication
sudo ufw allow 2375/tcp
sudo ufw allow 2376/tcp

# Allow Fabric peer ports
sudo ufw allow 7051/tcp
sudo ufw allow 7052/tcp
sudo ufw allow 7053/tcp

# Allow Fabric orderer ports
sudo ufw allow 7050/tcp
sudo ufw allow 7054/tcp

# Allow Fabric CA ports
sudo ufw allow 7054/tcp
sudo ufw allow 8054/tcp
sudo ufw allow 9054/tcp

# Reload firewall
sudo ufw reload
```

---

## Network Setup

### Step 1: Clone or Navigate to Project Directory

```bash
cd /home/valos/workspace/hyperledger/hyperledger-multihost
```

### Step 2: Prepare Environment

```bash
# Run prerequisites script
./scripts/00-prereqs.sh

# Set environment variables
export FABRIC_CFG_PATH=$PWD/config
export CORE_PEER_TLS_ENABLED=true
```

### Step 3: Set Up Org1 (Laptop 1)

#### 3.1 Bring Up Org1 CA

```bash
./scripts/01a-l1-up.sh
```

Wait for the CA container to start (check with `docker ps`).

#### 3.2 Enroll Org1 Admin and User

```bash
./scripts/02a-enroll-org1.sh
```

This script:
- Enrolls the Org1 admin
- Registers and enrolls the Org1 peer
- Generates required certificates

#### 3.3 Bring Up Org1 Peer Network

```bash
./scripts/01b-l1-up-peer.sh
```

Verify the peer is running:

```bash
docker ps | grep peer0.org1
docker logs peer0.org1.example.com
```

### Step 4: Join Channel

#### 4.1 Copy Channel Artifacts from Laptop 2

On Laptop 2, transfer these files to Laptop 1:

```bash
# On Laptop 2
cd /home/valos/workspace/hyperledger/hyperledger-multihost
scp channel-artifacts/mychannel.block valos@192.168.7.111:/home/valos/workspace/hyperledger/hyperledger-multihost/channel-artifacts/
scp channel-artifacts/Org1MSPanchors.tx valos@192.168.7.111:/home/valos/workspace/hyperledger/hyperledger-multihost/channel-artifacts/
```

#### 4.2 Join Org1 Peer to Channel

```bash
./scripts/07-l1-join-channel-org1-peer.sh
```

Verify the peer has joined:

```bash
peer channel list
```

Expected output:
```
Channels peers has joined:
mychannel
```

---

## Building the Client

### Step 1: Navigate to Client Directory

```bash
cd /home/valos/workspace/hyperledger/hyperledger-multihost/chaincode-client
```

### Step 2: Clean Previous Builds

```bash
# Remove existing binary
rm -f chaincode-client

# Clean Go modules
go clean -modcache
```

### Step 3: Initialize Go Module

```bash
go mod tidy
```

This will download any necessary dependencies (only standard library is used).

### Step 4: Build the Application

```bash
# Build for current architecture
go build -o chaincode-client main.go

# Make executable
chmod +x chaincode-client

# Verify build
ls -lh chaincode-client
```

Expected output: Binary ~3.2 MB

### Step 5: (Optional) Build for Different Architectures

```bash
# Build for Linux ARM64
GOARCH=arm64 go build -o chaincode-client-arm64 main.go

# Build for macOS AMD64
GOOS=darwin GOARCH=amd64 go build -o chaincode-client-macos main.go

# Build for Windows
GOOS=windows GOARCH=amd64 go build -o chaincode-client.exe main.go
```

---

## Chaincode Deployment

The chaincode must be deployed on the channel before using the client.

### Step 1: Package Chaincode (Laptop 2)

On Laptop 2:

```bash
cd /home/valos/workspace/hyperledger/hyperledger-multihost
./scripts/08-cc-package.sh
```

### Step 2: Install Chaincode on All Peers

#### On Laptop 2:

```bash
./scripts/09-l2-cc-install-org2.sh
./scripts/10-l2-cc-install-org3.sh
```

#### Transfer Package to Laptop 1:

On Laptop 2:

```bash
scp channel-artifacts/asset.tar.gz valos@192.168.7.111:/home/valos/workspace/hyperledger/hyperledger-multihost/channel-artifacts/
```

#### On Laptop 1:

```bash
./scripts/11-l1-cc-install-org1.sh
```

### Step 3: Approve Chaincode Definition

#### On Laptop 2:

```bash
./scripts/12-l2-cc-approve-org2.sh
./scripts/13-l2-cc-approve-org3.sh
```

#### On Laptop 1:

```bash
./scripts/14-l1-cc-approve-org1.sh
```

### Step 4: Commit Chaincode Definition (Laptop 2)

On Laptop 2:

```bash
./scripts/15-l2-cc-commit.sh
```

### Step 5: Verify Chaincode Deployment

Check that the chaincode is committed on the channel:

```bash
peer lifecycle chaincode querycommitted -C mychannel -o orderer.example.com:7050
```

Expected output:
```json
Committed chaincode definitions for channel 'mychannel':
Package name: asset, Sequence: 1, Version: 1.0, Endorsement plugin: escc, Validation plugin: vscc
```

---

## Using the Client

### Basic Usage

The client provides a command-line interface for all chaincode operations:

```bash
cd /home/valos/workspace/hyperledger/hyperledger-multihost/chaincode-client
./chaincode-client <command> [args]
```

### Command Reference

#### 1. Create Asset

Create a new asset with ID, owner, and value:

```bash
./chaincode-client create <asset-id> <owner> <value>
```

Example:

```bash
./chaincode-client create asset001 Alice 1000
```

Expected output:
```
Creating asset: ID=asset001, Owner=Alice, Value=1000
Asset created successfully:
[Chaincode output with transaction ID]
```

#### 2. Read Asset

Retrieve an asset by its ID:

```bash
./chaincode-client read <asset-id>
```

Example:

```bash
./chaincode-client read asset001
```

Expected output:
```
Reading asset: ID=asset001
Asset retrieved successfully:
  ID: asset001
  Owner: Alice
  Value: 1000
  CreatedAt: 2024-01-16T20:00:00Z
  UpdatedAt: 2024-01-16T20:00:00Z
  Version: 1
---

Asset Details:
  ID: asset001
  Owner: Alice
  Value: 1000
  CreatedAt: 2024-01-16T20:00:00Z
  UpdatedAt: 2024-01-16T20:00:00Z
  Version: 1
```

#### 3. Update Asset Owner

Transfer ownership of an asset:

```bash
./chaincode-client update-owner <asset-id> <new-owner>
```

Example:

```bash
./chaincode-client update-owner asset001 Bob
```

#### 4. Update Asset Value

Change the value of an asset:

```bash
./chaincode-client update-value <asset-id> <new-value>
```

Example:

```bash
./chaincode-client update-value asset001 2500
```

#### 5. Delete Asset

Remove an asset from the ledger:

```bash
./chaincode-client delete <asset-id>
```

Example:

```bash
./chaincode-client delete asset001
```

#### 6. Check Asset Existence

Verify if an asset exists:

```bash
./chaincode-client exists <asset-id>
```

Example:

```bash
./chaincode-client exists asset001
```

Expected output:
```
Checking if asset exists: ID=asset001
Asset exists: true

Asset asset001 exists: true
```

#### 7. List All Assets

Retrieve all assets from the ledger:

```bash
./chaincode-client list
```

Expected output:
```
Retrieving all assets...
Retrieved 2 assets:
  ID: asset001
  Owner: Alice
  Value: 1000
  CreatedAt: 2024-01-16T20:00:00Z
  UpdatedAt: 2024-01-16T20:00:00Z
  Version: 1
---
  ID: asset002
  Owner: Bob
  Value: 500
  CreatedAt: 2024-01-16T20:05:00Z
  UpdatedAt: 2024-01-16T20:05:00Z
  Version: 1
---

Found 2 assets:
```

---

## Testing and Verification

### Test 1: Basic Operations Workflow

Execute a complete workflow to verify all operations:

```bash
# 1. Create multiple assets
./chaincode-client create test_asset_1 Alice 100
./chaincode-client create test_asset_2 Bob 200
./chaincode-client create test_asset_3 Charlie 300

# 2. List all assets
./chaincode-client list

# 3. Read specific asset
./chaincode-client read test_asset_1

# 4. Update asset owner
./chaincode-client update-owner test_asset_1 David

# 5. Update asset value
./chaincode-client update-value test_asset_1 500

# 6. Verify update
./chaincode-client read test_asset_1

# 7. Check existence
./chaincode-client exists test_asset_1

# 8. Delete an asset
./chaincode-client delete test_asset_3

# 9. Verify deletion
./chaincode-client list
./chaincode-client exists test_asset_3
```

### Test 2: Error Handling

Test error scenarios:

```bash
# Test duplicate asset creation
./chaincode-client create duplicate_test Alice 100
./chaincode-client create duplicate_test Bob 200

# Test reading non-existent asset
./chaincode-client read non_existent_asset

# Test invalid value (should fail if implemented in chaincode)
./chaincode-client create invalid_asset Alice -100

# Test empty ID (should fail)
./chaincode-client create "" Alice 100
```

### Test 3: Network Resilience

Test the client's behavior with network issues:

```bash
# Stop peer container
docker stop peer0.org1.example.com

# Try to execute a query (should fail with connection error)
./chaincode-client list

# Start peer container
docker start peer0.org1.example.com

# Wait for peer to be ready
sleep 10

# Try again (should succeed)
./chaincode-client list
```

### Test 4: Concurrent Operations

Test multiple operations in sequence:

```bash
# Create multiple assets quickly
for i in {1..10}; do
  ./chaincode-client create "asset_$i" "User_$i" $((i * 100))
done

# List all assets
./chaincode-client list

# Update multiple assets
for i in {1..5}; do
  ./chaincode-client update-owner "asset_$i" "Updated_User_$i"
done

# Verify updates
./chaincode-client list
```

---

## Troubleshooting

### Issue 1: "peer: command not found"

**Symptom**: The client fails to execute peer commands.

**Solution**:

```bash
# Check if peer binary is in PATH
which peer

# If not found, add Fabric binaries to PATH
export PATH=$PATH:$HOME/fabric/bin
echo 'export PATH=$PATH:$HOME/fabric/bin' >> ~/.bashrc
source ~/.bashrc

# Verify
peer version
```

### Issue 2: "failed to connect to peer"

**Symptom**: Client cannot connect to the peer endpoint.

**Solution**:

```bash
# Check if peer container is running
docker ps | grep peer0.org1.example.com

# Check peer logs
docker logs peer0.org1.example.com --tail 50

# Verify network connectivity
ping peer0.org1.example.com
telnet peer0.org1.example.com 7051

# Check /etc/hosts
cat /etc/hosts | grep peer0.org1.example.com
```

### Issue 3: "chaincode basic not found"

**Symptom**: Chaincode is not installed or committed on the channel.

**Solution**:

```bash
# Check installed chaincodes
peer lifecycle chaincode queryinstalled

# Check committed chaincodes
peer lifecycle chaincode querycommitted -C mychannel

# If not found, follow the chaincode deployment steps in this guide
```

### Issue 4: "Access denied" or "Permission denied"

**Symptom**: The client doesn't have permission to execute transactions.

**Solution**:

```bash
# Check if admin credentials exist
ls -la organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/

# Re-enroll admin if needed
cd /home/valos/workspace/hyperledger/hyperledger-multihost
./scripts/02a-enroll-org1.sh
```

### Issue 5: TLS Certificate Errors

**Symptom**: Errors related to TLS certificates.

**Solution**:

```bash
# Verify TLS certificates exist
ls -la organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/

# Check certificate expiration
openssl x509 -in organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -text -noout | grep "Not After"

# If expired, re-enroll peer
./scripts/02a-enroll-org1.sh
```

### Issue 6: JSON Parsing Errors

**Symptom**: Client fails to parse chaincode responses.

**Solution**:

```bash
# Test peer CLI directly
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'
```

### Issue 7: "timeout waiting for event"

**Symptom**: Invoke operations timeout waiting for transaction commit.

**Solution**:

```bash
# Check orderer is running
docker ps | grep orderer

# Check orderer logs
docker logs orderer.example.com --tail 50

# Verify channel is active
peer channel getinfo -c mychannel

# If orderer is down, restart it
docker restart orderer.example.com
```

---

## Advanced Configuration

### Customizing Configuration

To customize the client configuration, edit the `init()` function in `main.go`:

```go
func init() {
    homeDir := "/home/valos/workspace/hyperledger/hyperledger-multihost"
    config = Config{
        PeerBinary:     "peer",  // Path to peer binary
        ChannelName:    "mychannel",
        ChaincodeName:  "basic",
        PeerAddress:    "peer0.org1.example.com",
        PeerPort:       "7051",
        OrdererAddress: "orderer.example.com:7050",
        OrgMSP:         "Org1MSP",
        UserPath:       filepath.Join(homeDir, "organizations", "peerOrganizations", "org1.example.com", "users", "Admin@org1.example.com", "msp"),
        TLSCertFile:    filepath.Join(homeDir, "organizations", "peerOrganizations", "org1.example.com", "peers", "peer0.org1.example.com", "tls", "ca.crt"),
        HomeDir:        homeDir,
    }
}
```

### Using Environment Variables

Modify the client to read configuration from environment variables:

```go
// Add to init() function
config.PeerAddress = os.Getenv("CORE_PEER_ADDRESS")
config.UserPath = os.Getenv("CORE_PEER_MSPCONFIGPATH")
config.TLSCertFile = os.Getenv("CORE_PEER_TLS_ROOTCERT_FILE")
```

Then run:

```bash
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051
export CORE_PEER_MSPCONFIGPATH=/path/to/msp
export CORE_PEER_TLS_ROOTCERT_FILE=/path/to/tls/cert
./chaincode-client list
```

### Logging Configuration

Enable detailed logging by modifying the runPeerCommand function:

```go
func runPeerCommand(args ...string) (string, error) {
    // ... existing code ...
    
    // Enable debug logging
    cmd.Env = append(env, "FABRIC_LOGGING_SPEC=debug")
    
    // ... rest of the function ...
}
```

### Performance Tuning

For better performance with large datasets:

1. **Batch Operations**: Modify the client to support batch creates/updates
2. **Connection Pooling**: Reuse peer connections if implementing gRPC directly
3. **Caching**: Implement client-side caching for frequently accessed assets

---

## Integration with Existing Systems

### Integrating with REST API

Create a simple REST API wrapper:

```go
// rest-api.go (additional file)
package main

import (
    "encoding/json"
    "net/http"
)

func handleCreate(w http.ResponseWriter, r *http.Request) {
    var req struct {
        ID    string `json:"id"`
        Owner string `json:"owner"`
        Value int64  `json:"value"`
    }
    json.NewDecoder(r.Body).Decode(&req)
    
    err := CreateAsset(req.ID, req.Owner, req.Value)
    if err != nil {
        http.Error(w, err.Error(), 500)
        return
    }
    w.WriteHeader(http.StatusCreated)
}

func main() {
    http.HandleFunc("/create", handleCreate)
    http.HandleFunc("/read", handleRead)
    http.HandleFunc("/list", handleList)
    http.ListenAndServe(":8080", nil)
}
```

### Integrating with CI/CD

Add to your CI/CD pipeline:

```yaml
# .github/workflows/test-chaincode.yml
name: Test Chaincode Client

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.22
      - name: Build client
        run: |
          cd chaincode-client
          go build -o chaincode-client main.go
      - name: Run tests
        run: |
          # Add test commands here
          ./chaincode-client create test_ci User1 100
          ./chaincode-client read test_ci
```

---

## Security Best Practices

### 1. Credential Management

- Never commit private keys to version control
- Use environment variables or secret management for sensitive data
- Rotate certificates regularly

### 2. Access Control

- Run the client with minimal required permissions
- Use role-based access control (RBAC) if available
- Implement audit logging for all operations

### 3. Network Security

- Use TLS for all network communications
- Configure firewall rules appropriately
- Use VPN or secure tunnels for remote access

### 4. Code Security

- Keep dependencies updated
- Perform regular security audits
- Use static analysis tools

---

## Maintenance and Updates

### Updating the Client

When new chaincode functions are added:

1. Update the `Asset` struct if the data model changes
2. Add new wrapper functions for each chaincode operation
3. Update the README.md with new commands
4. Rebuild and test

### Updating Chaincode

When the chaincode version is updated:

1. Package the new chaincode version
2. Install on all peers
3. Approve the new definition
4. Commit the new definition
5. Test the client with the new version

### Monitoring

Monitor the client and network health:

```bash
# Check peer health
docker ps | grep peer
docker logs peer0.org1.example.com --tail 100

# Check chaincode logs
docker logs peer0.org1.example.com 2>&1 | grep chaincode

# Monitor system resources
top
htop
df -h
```

---

## Support and Resources

### Documentation

- [Hyperledger Fabric Documentation](https://hyperledger-fabric.readthedocs.io/)
- [Chaincode Development Guide](https://hyperledger-fabric.readthedocs.io/en/latest/developapps/developing_applications.html)
- [Peer CLI Reference](https://hyperledger-fabric.readthedocs.io/en/latest/commands/peercommand.html)

### Community

- [Hyperledger Fabric Chat](https://chat.hyperledger.org/channel/fabric)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/hyperledger-fabric)
- [GitHub Issues](https://github.com/hyperledger/fabric/issues)

### Getting Help

If you encounter issues:

1. Check the troubleshooting section
2. Review peer and orderer logs
3. Consult the Fabric documentation
4. Search existing GitHub issues
5. Ask in the Hyperledger Fabric chat

---

## Appendix

### A. Directory Structure

```
hyperledger-multihost/
├── chaincode/
│   └── asset/
│       ├── asset_contract.go
│       ├── main.go
│       ├── models.go
│       ├── go.mod
│       └── go.sum
├── chaincode-client/
│   ├── main.go              # Client application
│   ├── go.mod              # Go module definition
│   ├── README.md           # Client documentation
│   └── chaincode-client    # Compiled binary
├── channel-artifacts/
│   ├── mychannel.block     # Channel genesis block
│   ├── Org1MSPanchors.tx   # Anchor peer transaction
│   └── asset.tar.gz        # Chaincode package
├── organizations/
│   ├── peerOrganizations/
│   │   └── org1.example.com/
│   │       ├── users/
│   │       │   └── Admin@org1.example.com/
│   │       │       └── msp/          # Admin credentials
│   │       └── peers/
│   │           └── peer0.org1.example.com/
│   │               └── tls/           # TLS certificates
│   └── ordererOrganizations/
├── config/
│   ├── core.yaml           # Peer configuration
│   ├── orderer.yaml        # Orderer configuration
│   └── configtx.yaml       # Channel configuration
└── scripts/
    ├── 00-prereqs.sh
    ├── 01a-l1-up.sh
    ├── 01b-l1-up-peer.sh
    ├── 02a-enroll-org1.sh
    ├── 07-l1-join-channel-org1-peer.sh
    └── ...
```

### B. Environment Variables

Key environment variables used by the client:

```bash
CORE_PEER_TLS_ENABLED=true
CORE_PEER_LOCALMSPID=Org1MSP
CORE_PEER_TLS_ROOTCERT_FILE=<path-to-tls-cert>
CORE_PEER_MSPCONFIGPATH=<path-to-admin-msp>
CORE_PEER_ADDRESS=peer0.org1.example.com:7051
FABRIC_CFG_PATH=<path-to-config-dir>
```

### C. Port Reference

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Peer | 7051 | gRPC | Peer service endpoint |
| Peer CLI | 7052 | gRPC | Peer CLI endpoint |
| Peer Events | 7053 | gRPC | Peer event hub |
| Orderer | 7050 | gRPC | Orderer service |
| Org1 CA | 7054 | HTTP | Fabric CA for Org1 |
| Org2 CA | 8054 | HTTP | Fabric CA for Org2 |
| Org3 CA | 9054 | HTTP | Fabric CA for Org3 |

### D. Common Commands

```bash
# Check peer status
docker ps | grep peer

# View peer logs
docker logs peer0.org1.example.com -f

# Check channel info
peer channel getinfo -c mychannel

# List installed chaincodes
peer lifecycle chaincode queryinstalled

# List committed chaincodes
peer lifecycle chaincode querycommitted -C mychannel

# Query block height
peer channel fetch newest mychannel.block -c mychannel
```

---

**End of Deployment Guide**