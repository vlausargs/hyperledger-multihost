# Fabric Chaincode Client for Laptop 1 (Org1)

A Go application to interact with Hyperledger Fabric chaincode on Laptop 1 without using the deprecated `fabric-sdk-go`. This client wraps the Fabric peer CLI binary to execute chaincode operations.

## Overview

This application allows you to perform all basic asset management operations on the `basic` chaincode deployed to the `mychannel` channel:
- Create assets
- Read assets
- Update asset owner and value
- Delete assets
- Check if an asset exists
- List all assets

## Prerequisites

1. **Fabric Peer Binary**: The `peer` binary must be installed and available in your PATH
2. **Fabric Network**: The Fabric network must be running and configured
3. **Chaincode Deployed**: The `basic` chaincode must be installed and committed on the `mychannel` channel
4. **User Identity**: Admin user credentials for Org1 must be enrolled at:
   ```
   organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
   ```

## Building

Navigate to the chaincode-client directory and build the application:

```bash
cd /home/valos/workspace/hyperledger/hyperledger-multihost/chaincode-client
go mod tidy
go build -o chaincode-client main.go
```

## Configuration

The client uses the following hardcoded configuration (you can modify these in `main.go`):

| Setting | Value | Description |
|---------|-------|-------------|
| Channel Name | `mychannel` | The Fabric channel to interact with |
| Chaincode Name | `basic` | The chaincode name |
| Peer Address | `peer0.org1.example.com:7051` | Org1 peer endpoint |
| Orderer Address | `orderer.example.com:7050` | Orderer endpoint |
| Org MSP | `Org1MSP` | Organization MSP ID |
| User MSP Path | `organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp` | Admin user credentials |

## Usage

### Basic Syntax

```bash
./chaincode-client <command> [arguments]
```

### Commands

#### Create an Asset

Create a new asset with an ID, owner, and value:

```bash
./chaincode-client create <id> <owner> <value>
```

Example:
```bash
./chaincode-client create asset1 Alice 100
```

#### Read an Asset

Read an asset by its ID:

```bash
./chaincode-client read <id>
```

Example:
```bash
./chaincode-client read asset1
```

#### Update Asset Owner

Change the owner of an existing asset:

```bash
./chaincode-client update-owner <id> <newOwner>
```

Example:
```bash
./chaincode-client update-owner asset1 Bob
```

#### Update Asset Value

Change the value of an existing asset:

```bash
./chaincode-client update-value <id> <newValue>
```

Example:
```bash
./chaincode-client update-value asset1 200
```

#### Delete an Asset

Delete an asset by its ID:

```bash
./chaincode-client delete <id>
```

Example:
```bash
./chaincode-client delete asset1
```

#### Check if Asset Exists

Check if an asset exists in the ledger:

```bash
./chaincode-client exists <id>
```

Example:
```bash
./chaincode-client exists asset1
```

#### List All Assets

Retrieve and display all assets:

```bash
./chaincode-client list
```

## Complete Workflow Example

```bash
# 1. Create a new asset
./chaincode-client create asset1 Alice 100

# 2. Read the asset to verify creation
./chaincode-client read asset1

# 3. Update the asset owner
./chaincode-client update-owner asset1 Bob

# 4. Update the asset value
./chaincode-client update-value asset1 250

# 5. Check if the asset exists
./chaincode-client exists asset1

# 6. List all assets to see changes
./chaincode-client list

# 7. Delete the asset when done
./chaincode-client delete asset1
```

## How It Works

This client uses the `os/exec` package to execute Fabric peer CLI commands with proper environment variables and arguments:

1. **Query Operations** (read, exists, list): Uses `peer chaincode query`
2. **Invoke Operations** (create, update-owner, update-value, delete): Uses `peer chaincode invoke`

The application handles:
- TLS configuration
- MSP identity
- JSON argument serialization
- Output parsing and error handling

## Troubleshooting

### Error: "peer: command not found"

Ensure the Fabric peer binary is installed and in your PATH. Check with:
```bash
peer version
```

### Error: "failed to connect to orderer"

Verify that:
1. The Fabric network is running
2. The orderer endpoint is correct
3. TLS certificates are properly configured

### Error: "failed to create asset: Access denied"

Ensure:
1. The Admin user credentials exist at the configured path
2. The user has proper permissions
3. The MSP ID is correct

## Notes

- This client is specifically configured for **Org1** on **Laptop 1**
- All transactions require endorsement from peers as per the network's endorsement policy
- Invoke operations wait for transaction events to confirm successful commit
- The client assumes the Fabric network is running and accessible

## Architecture

The application is structured as follows:

- **Config**: Holds configuration parameters for peer connection and identity
- **Asset**: Data structure representing the chaincode asset
- **runPeerCommand()**: Executes peer CLI commands with environment setup
- **invokeChaincode()**: Handles write operations (create, update, delete)
- **queryChaincode()**: Handles read operations (read, exists, list)
- **Operation Functions**: Wrapper functions for each chaincode operation

## License

This code is provided as-is for the Hyperledger Fabric multi-host setup.