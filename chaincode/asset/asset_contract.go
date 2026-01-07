package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type AssetContract struct {
	contractapi.Contract
}

func (c *AssetContract) CreateAsset(ctx contractapi.TransactionContextInterface, id string, owner string, value int64) error {
	id = strings.TrimSpace(id)
	owner = strings.TrimSpace(owner)

	if id == "" {
		return errors.New("id is required")
	}
	if owner == "" {
		return errors.New("owner is required")
	}
	if value < 0 {
		return errors.New("value must be >= 0")
	}

	exists, err := c.AssetExists(ctx, id)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("asset %s already exists", id)
	}

	now, err := txTimeRFC3339(ctx)
	if err != nil {
		return err
	}

	asset := Asset{
		ID:        id,
		Owner:     owner,
		Value:     value,
		CreatedAt: now,
		UpdatedAt: now,
		Version:   1,
	}

	b, err := json.Marshal(asset)
	if err != nil {
		return fmt.Errorf("marshal asset: %w", err)
	}

	return ctx.GetStub().PutState(id, b)
}

func (c *AssetContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	id = strings.TrimSpace(id)
	if id == "" {
		return nil, errors.New("id is required")
	}

	b, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("get state: %w", err)
	}
	if b == nil {
		return nil, fmt.Errorf("asset %s not found", id)
	}

	var asset Asset
	if err := json.Unmarshal(b, &asset); err != nil {
		return nil, fmt.Errorf("unmarshal asset: %w", err)
	}
	return &asset, nil
}

func (c *AssetContract) UpdateAssetOwner(ctx contractapi.TransactionContextInterface, id string, newOwner string) error {
	newOwner = strings.TrimSpace(newOwner)
	if newOwner == "" {
		return errors.New("newOwner is required")
	}

	asset, err := c.ReadAsset(ctx, id)
	if err != nil {
		return err
	}

	now, err := txTimeRFC3339(ctx)
	if err != nil {
		return err
	}

	asset.Owner = newOwner
	asset.UpdatedAt = now
	asset.Version++

	b, err := json.Marshal(asset)
	if err != nil {
		return fmt.Errorf("marshal asset: %w", err)
	}
	return ctx.GetStub().PutState(asset.ID, b)
}

func (c *AssetContract) UpdateAssetValue(ctx contractapi.TransactionContextInterface, id string, newValue int64) error {
	if newValue < 0 {
		return errors.New("newValue must be >= 0")
	}

	asset, err := c.ReadAsset(ctx, id)
	if err != nil {
		return err
	}

	now, err := txTimeRFC3339(ctx)
	if err != nil {
		return err
	}

	asset.Value = newValue
	asset.UpdatedAt = now
	asset.Version++

	b, err := json.Marshal(asset)
	if err != nil {
		return fmt.Errorf("marshal asset: %w", err)
	}
	return ctx.GetStub().PutState(asset.ID, b)
}

func (c *AssetContract) DeleteAsset(ctx contractapi.TransactionContextInterface, id string) error {
	_, err := c.ReadAsset(ctx, id)
	if err != nil {
		return err
	}
	return ctx.GetStub().DelState(id)
}

func (c *AssetContract) AssetExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	id = strings.TrimSpace(id)
	if id == "" {
		return false, errors.New("id is required")
	}

	b, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, fmt.Errorf("get state: %w", err)
	}
	return b != nil, nil
}

func (c *AssetContract) GetAllAssets(ctx contractapi.TransactionContextInterface) ([]*Asset, error) {
	iter, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, fmt.Errorf("range query: %w", err)
	}
	defer iter.Close()

	var out []*Asset
	for iter.HasNext() {
		kv, err := iter.Next()
		if err != nil {
			return nil, fmt.Errorf("iter next: %w", err)
		}
		var a Asset
		if err := json.Unmarshal(kv.Value, &a); err != nil {
			return nil, fmt.Errorf("unmarshal: %w", err)
		}
		out = append(out, &a)
	}
	return out, nil
}

func txTimeRFC3339(ctx contractapi.TransactionContextInterface) (string, error) {
	ts, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return "", fmt.Errorf("get tx timestamp: %w", err)
	}
	t := time.Unix(int64(ts.Seconds), int64(ts.Nanos)).UTC()
	return t.Format(time.RFC3339Nano), nil
}
