package main

import (
	"log"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func main() {
	chaincode, err := contractapi.NewChaincode(&AssetContract{})
	if err != nil {
		log.Panicf("Error creating chaincode: %v", err)
	}

	chaincode.Info.Title = "asset"
	chaincode.Info.Version = "1.0"

	if err := chaincode.Start(); err != nil {
		log.Panicf("Error starting chaincode: %v", err)
	}
}
