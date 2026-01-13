package enroll

import (
	"fmt"
	"os"
	"path/filepath"
)

func EnsureNodeOUsConfig(orgHome string) error {
	// Locate the CA cert under orgHome/msp/cacerts/*.pem
	cacertsDir := filepath.Join(orgHome, "msp", "cacerts")
	matches, err := filepath.Glob(filepath.Join(cacertsDir, "*.pem"))
	if err != nil {
		return err
	}
	if len(matches) == 0 {
		return fmt.Errorf("no cacerts found in %s; ensure CA admin enroll succeeded", cacertsDir)
	}
	caCertBase := filepath.Base(matches[0])

	cfgPath := filepath.Join(orgHome, "msp", "config.yaml")
	content := fmt.Sprintf(`NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/%s
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/%s
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/%s
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/%s
    OrganizationalUnitIdentifier: orderer
`, caCertBase, caCertBase, caCertBase, caCertBase)

	return os.WriteFile(cfgPath, []byte(content), 0o644)
}
