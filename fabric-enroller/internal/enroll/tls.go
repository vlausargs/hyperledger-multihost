package enroll

import (
	"fmt"
	"path/filepath"

	"fabric-enroller/internal/util"
)

func StandardizeTLSFilenames(tlsDir string) error {
	// Expect Fabric CA TLS layout:
	//   tlscacerts/*, signcerts/*, keystore/*
	tlsca, err := firstFile(filepath.Join(tlsDir, "tlscacerts", "*"))
	if err != nil {
		return fmt.Errorf("tlscacerts: %w", err)
	}
	signcert, err := firstFile(filepath.Join(tlsDir, "signcerts", "*"))
	if err != nil {
		return fmt.Errorf("signcerts: %w", err)
	}
	key, err := firstFile(filepath.Join(tlsDir, "keystore", "*"))
	if err != nil {
		return fmt.Errorf("keystore: %w", err)
	}

	if err := util.CopyFile(tlsca, filepath.Join(tlsDir, "ca.crt")); err != nil {
		return err
	}
	if err := util.CopyFile(signcert, filepath.Join(tlsDir, "server.crt")); err != nil {
		return err
	}
	if err := util.CopyFile(key, filepath.Join(tlsDir, "server.key")); err != nil {
		return err
	}
	return nil
}

func StandardizeClientTLSFilenames(tlsDir string) error {
	tlsca, err := firstFile(filepath.Join(tlsDir, "tlscacerts", "*"))
	if err != nil {
		return fmt.Errorf("tlscacerts: %w", err)
	}
	signcert, err := firstFile(filepath.Join(tlsDir, "signcerts", "*"))
	if err != nil {
		return fmt.Errorf("signcerts: %w", err)
	}
	key, err := firstFile(filepath.Join(tlsDir, "keystore", "*"))
	if err != nil {
		return fmt.Errorf("keystore: %w", err)
	}

	if err := util.CopyFile(tlsca, filepath.Join(tlsDir, "ca.crt")); err != nil {
		return err
	}
	if err := util.CopyFile(signcert, filepath.Join(tlsDir, "client.crt")); err != nil {
		return err
	}
	if err := util.CopyFile(key, filepath.Join(tlsDir, "client.key")); err != nil {
		return err
	}
	return nil
}


func firstFile(glob string) (string, error) {
	m, err := filepath.Glob(glob)
	if err != nil {
		return "", err
	}
	if len(m) == 0 {
		return "", fmt.Errorf("no matches for %s", glob)
	}
	return m[0], nil
}
