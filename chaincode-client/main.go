package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// Config holds the configuration for the chaincode client
type Config struct {
	PeerBinary             string
	ChannelName            string
	ChaincodeName          string
	PeerAddress            string
	PeerPort               string
	OrdererAddress         string
	OrgMSP                 string
	UserPath               string
	TLSCertFile            string
	OrdererTLSRootCertFile string
	HomeDir                string
	// Org2 peer configuration for multi-peer endorsement
	Peer2Address     string
	Peer2Port        string
	Peer2TLSCertFile string
}

// Asset represents the chaincode asset structure
type Asset struct {
	ID        string `json:"ID"`
	Owner     string `json:"Owner"`
	Value     int64  `json:"Value"`
	CreatedAt string `json:"CreatedAt"`
	UpdatedAt string `json:"UpdatedAt"`
	Version   int    `json:"Version"`
}

var config Config

func init() {
	// Set up configuration based on the project structure
	homeDir := "/home/valos/workspace/hyperledger/hyperledger-multihost"
	config = Config{
		PeerBinary:             "peer", // Assumes peer binary is in PATH
		ChannelName:            "mychannel",
		ChaincodeName:          "asset",
		PeerAddress:            "peer0.org1.example.com",
		PeerPort:               "7051",
		OrdererAddress:         "orderer.example.com:7050",
		OrgMSP:                 "Org1MSP",
		UserPath:               filepath.Join(homeDir, "organizations", "peerOrganizations", "org1.example.com", "users", "Admin@org1.example.com", "msp"),
		TLSCertFile:            filepath.Join(homeDir, "organizations", "peerOrganizations", "org1.example.com", "peers", "peer0.org1.example.com", "tls", "ca.crt"),
		OrdererTLSRootCertFile: filepath.Join(homeDir, "organizations", "ordererOrganizations", "example.com", "orderers", "orderer.example.com", "tls", "ca.crt"),
		HomeDir:                homeDir,
		// Org2 peer configuration for multi-peer endorsement
		Peer2Address:     "peer0.org2.example.com",
		Peer2Port:        "9051",
		Peer2TLSCertFile: filepath.Join(homeDir, "organizations", "peerOrganizations", "org2.example.com", "peers", "peer0.org2.example.com", "tls", "ca.crt"),
	}
}

// runPeerCommand executes a peer CLI command with proper environment variables
func runPeerCommand(args ...string) (string, error) {
	// Set up environment variables for peer CLI
	env := []string{
		// fmt.Sprintf("CORE_PEER_TLS_ENABLED=true"),
		fmt.Sprintf("CORE_PEER_LOCALMSPID=%s", config.OrgMSP),
		fmt.Sprintf("CORE_PEER_TLS_ROOTCERT_FILE=%s", config.TLSCertFile),
		fmt.Sprintf("CORE_PEER_MSPCONFIGPATH=%s", config.UserPath),
		fmt.Sprintf("CORE_PEER_ADDRESS=%s:%s", config.PeerAddress, config.PeerPort),
		fmt.Sprintf("FABRIC_CFG_PATH=%s", filepath.Join(config.HomeDir, "config")),
	}

	// Append existing environment variables
	env = append(env, os.Environ()...)

	// Create the command
	cmd := exec.Command(config.PeerBinary, args...)
	cmd.Env = env

	// Run the command
	output, err := cmd.CombinedOutput()
	if err != nil {
		return string(output), fmt.Errorf("peer command failed: %w\nOutput: %s", err, string(output))
	}

	return string(output), nil
}

// invokeChaincode executes a chaincode invoke operation (write)
func invokeChaincode(function string, args ...string) (string, error) {
	// Build the JSON args array
	argsJSON := buildArgsJSON(function, args...)

	// Execute peer chaincode invoke with multi-peer endorsement (Org1 + Org2)
	fmt.Printf("Requesting endorsement from Org1 (%s:%s) and Org2 (%s:%s)\n",
		config.PeerAddress, config.PeerPort, config.Peer2Address, config.Peer2Port)

	output, err := runPeerCommand(
		"chaincode", "invoke",
		"-o", config.OrdererAddress,
		"--tls",
		"--cafile", config.OrdererTLSRootCertFile,
		"-C", config.ChannelName,
		"-n", config.ChaincodeName,
		"-c", argsJSON,
		"--peerAddresses", fmt.Sprintf("%s:%s", config.PeerAddress, config.PeerPort),
		"--tlsRootCertFiles", config.TLSCertFile,
		"--peerAddresses", fmt.Sprintf("%s:%s", config.Peer2Address, config.Peer2Port),
		"--tlsRootCertFiles", config.Peer2TLSCertFile,
		"--waitForEvent",
	)

	return output, err
}

// queryChaincode executes a chaincode query operation (read)
func queryChaincode(function string, args ...string) (string, error) {
	// Build the JSON args array
	argsJSON := buildArgsJSON(function, args...)

	// Execute peer chaincode query
	output, err := runPeerCommand(
		"chaincode", "query",
		"-C", config.ChannelName,
		"-n", config.ChaincodeName,
		"-c", argsJSON,
	)

	return output, err
}

// buildArgsJSON builds the JSON args object for chaincode invocation
func buildArgsJSON(function string, args ...string) string {
	allArgs := append([]string{function}, args...)
	argsMap := map[string]interface{}{
		"Args": allArgs,
	}
	argsBytes, _ := json.Marshal(argsMap)
	return string(argsBytes)
}

// CreateAsset creates a new asset
func CreateAsset(id, owner string, value int64) error {
	fmt.Printf("Creating asset: ID=%s, Owner=%s, Value=%d\n", id, owner, value)

	output, err := invokeChaincode("CreateAsset", id, owner, strconv.FormatInt(value, 10))
	if err != nil {
		return fmt.Errorf("failed to create asset: %w\nOutput: %s", err, output)
	}

	fmt.Printf("Asset created successfully:\n%s\n", output)
	return nil
}

// ReadAsset reads an asset by ID
func ReadAsset(id string) (*Asset, error) {
	fmt.Printf("Reading asset: ID=%s\n", id)

	output, err := queryChaincode("ReadAsset", id)
	if err != nil {
		return nil, fmt.Errorf("failed to read asset: %w\nOutput: %s", err, output)
	}

	var asset Asset
	if err := json.Unmarshal([]byte(strings.TrimSpace(output)), &asset); err != nil {
		return nil, fmt.Errorf("failed to parse asset JSON: %w\nOutput: %s", err, output)
	}

	fmt.Printf("Asset retrieved successfully:\n")
	printAsset(&asset)
	return &asset, nil
}

// UpdateAssetOwner updates the owner of an asset
func UpdateAssetOwner(id, newOwner string) error {
	fmt.Printf("Updating asset owner: ID=%s, NewOwner=%s\n", id, newOwner)

	output, err := invokeChaincode("UpdateAssetOwner", id, newOwner)
	if err != nil {
		return fmt.Errorf("failed to update asset owner: %w\nOutput: %s", err, output)
	}

	fmt.Printf("Asset owner updated successfully:\n%s\n", output)
	return nil
}

// UpdateAssetValue updates the value of an asset
func UpdateAssetValue(id string, newValue int64) error {
	fmt.Printf("Updating asset value: ID=%s, NewValue=%d\n", id, newValue)

	output, err := invokeChaincode("UpdateAssetValue", id, strconv.FormatInt(newValue, 10))
	if err != nil {
		return fmt.Errorf("failed to update asset value: %w\nOutput: %s", err, output)
	}

	fmt.Printf("Asset value updated successfully:\n%s\n", output)
	return nil
}

// DeleteAsset deletes an asset
func DeleteAsset(id string) error {
	fmt.Printf("Deleting asset: ID=%s\n", id)

	output, err := invokeChaincode("DeleteAsset", id)
	if err != nil {
		return fmt.Errorf("failed to delete asset: %w\nOutput: %s", err, output)
	}

	fmt.Printf("Asset deleted successfully:\n%s\n", output)
	return nil
}

// AssetExists checks if an asset exists
func AssetExists(id string) (bool, error) {
	fmt.Printf("Checking if asset exists: ID=%s\n", id)

	output, err := queryChaincode("AssetExists", id)
	if err != nil {
		return false, fmt.Errorf("failed to check asset existence: %w\nOutput: %s", err, output)
	}

	exists := strings.TrimSpace(output) == "true"
	fmt.Printf("Asset exists: %v\n", exists)
	return exists, nil
}

// GetAllAssets retrieves all assets
func GetAllAssets() ([]*Asset, error) {
	fmt.Println("Retrieving all assets...")

	output, err := queryChaincode("GetAllAssets")
	if err != nil {
		return nil, fmt.Errorf("failed to get all assets: %w\nOutput: %s", err, output)
	}

	var assets []*Asset
	if err := json.Unmarshal([]byte(strings.TrimSpace(output)), &assets); err != nil {
		return nil, fmt.Errorf("failed to parse assets JSON: %w\nOutput: %s", err, output)
	}

	fmt.Printf("Retrieved %d assets:\n", len(assets))
	for _, asset := range assets {
		printAsset(asset)
	}
	return assets, nil
}

// printAsset prints an asset in a formatted way
func printAsset(asset *Asset) {
	fmt.Printf("  ID: %s\n", asset.ID)
	fmt.Printf("  Owner: %s\n", asset.Owner)
	fmt.Printf("  Value: %d\n", asset.Value)
	fmt.Printf("  CreatedAt: %s\n", asset.CreatedAt)
	fmt.Printf("  UpdatedAt: %s\n", asset.UpdatedAt)
	fmt.Printf("  Version: %d\n", asset.Version)
	fmt.Println("---")
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: ./chaincode-client <command> [args...]")
		fmt.Println("\nCommands:")
		fmt.Println("  create <id> <owner> <value>    - Create a new asset")
		fmt.Println("  read <id>                       - Read an asset by ID")
		fmt.Println("  update-owner <id> <newOwner>   - Update asset owner")
		fmt.Println("  update-value <id> <newValue>   - Update asset value")
		fmt.Println("  delete <id>                    - Delete an asset")
		fmt.Println("  exists <id>                    - Check if asset exists")
		fmt.Println("  list                           - List all assets")
		os.Exit(1)
	}

	command := os.Args[1]

	switch command {
	case "create":
		if len(os.Args) != 5 {
			fmt.Println("Usage: ./chaincode-client create <id> <owner> <value>")
			os.Exit(1)
		}
		id := os.Args[2]
		owner := os.Args[3]
		value, err := strconv.ParseInt(os.Args[4], 10, 64)
		if err != nil {
			fmt.Printf("Invalid value: %s\n", os.Args[4])
			os.Exit(1)
		}
		if err := CreateAsset(id, owner, value); err != nil {
			fmt.Printf("Error: %v\n", err)
			os.Exit(1)
		}

	case "read":
		if len(os.Args) != 3 {
			fmt.Println("Usage: ./chaincode-client read <id>")
			os.Exit(1)
		}
		id := os.Args[2]
		asset, err := ReadAsset(id)
		if err != nil {
			fmt.Printf("Error: %v\n", err)
			os.Exit(1)
		}
		if asset != nil {
			fmt.Printf("\nAsset Details:\n")
			printAsset(asset)
		}

	case "update-owner":
		if len(os.Args) != 4 {
			fmt.Println("Usage: ./chaincode-client update-owner <id> <newOwner>")
			os.Exit(1)
		}
		id := os.Args[2]
		newOwner := os.Args[3]
		if err := UpdateAssetOwner(id, newOwner); err != nil {
			fmt.Printf("Error: %v\n", err)
			os.Exit(1)
		}

	case "update-value":
		if len(os.Args) != 4 {
			fmt.Println("Usage: ./chaincode-client update-value <id> <newValue>")
			os.Exit(1)
		}
		id := os.Args[2]
		newValue, err := strconv.ParseInt(os.Args[3], 10, 64)
		if err != nil {
			fmt.Printf("Invalid value: %s\n", os.Args[3])
			os.Exit(1)
		}
		if err := UpdateAssetValue(id, newValue); err != nil {
			fmt.Printf("Error: %v\n", err)
			os.Exit(1)
		}

	case "delete":
		if len(os.Args) != 3 {
			fmt.Println("Usage: ./chaincode-client delete <id>")
			os.Exit(1)
		}
		id := os.Args[2]
		if err := DeleteAsset(id); err != nil {
			fmt.Printf("Error: %v\n", err)
			os.Exit(1)
		}

	case "exists":
		if len(os.Args) != 3 {
			fmt.Println("Usage: ./chaincode-client exists <id>")
			os.Exit(1)
		}
		id := os.Args[2]
		exists, err := AssetExists(id)
		if err != nil {
			fmt.Printf("Error: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("\nAsset %s exists: %v\n", id, exists)

	case "list":
		assets, err := GetAllAssets()
		if err != nil {
			fmt.Printf("Error: %v\n", err)
			os.Exit(1)
		}
		if len(assets) == 0 {
			fmt.Println("\nNo assets found.")
		} else {
			fmt.Printf("\nFound %d assets:\n", len(assets))
		}

	default:
		fmt.Printf("Unknown command: %s\n", command)
		fmt.Println("Use 'help' to see available commands")
		os.Exit(1)
	}
}
