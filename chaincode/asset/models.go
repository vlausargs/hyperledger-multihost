package main

type Asset struct {
	ID        string `json:"id"`
	Owner     string `json:"owner"`
	Value     int64  `json:"value"`
	CreatedAt string `json:"createdAt"`
	UpdatedAt string `json:"updatedAt"`
	Version   int64  `json:"version"`
}
