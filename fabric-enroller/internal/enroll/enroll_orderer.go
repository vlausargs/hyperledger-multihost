package enroll

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"fabric-enroller/internal/fabricca"
	"fabric-enroller/internal/util"
)

type EnrollOrdererConfig struct {
	RootDir string
	Domain  string
	Orderer string // e.g. "orderer"

	Clean    bool
	FixPerms bool

	CA    CAConfig
	TLSCA CAConfig

	RegisterOnCA    []IdentitySpec
	RegisterOnTLSCA []IdentitySpec

	EnrollAdminTLS bool
}

func RunEnrollOrderer(cfg EnrollOrdererConfig, client *fabricca.Client) error {
	if strings.TrimSpace(cfg.RootDir) == "" {
		return fmt.Errorf("root dir is required")
	}
	if strings.TrimSpace(cfg.Domain) == "" {
		return fmt.Errorf("domain is required")
	}
	if strings.TrimSpace(cfg.Orderer) == "" {
		cfg.Orderer = "orderer"
	}

	ordererFQDN := fmt.Sprintf("%s.%s", cfg.Orderer, cfg.Domain)

	orgHome := filepath.Join(cfg.RootDir, "organizations", "ordererOrganizations", cfg.Domain)
	tlscaClientHome := filepath.Join(orgHome, ".tlsca-client")

	if cfg.FixPerms {
		orgsDir := filepath.Join(cfg.RootDir, "organizations")
		_ = util.ChownRToCurrentUser(orgsDir)
	}
	if cfg.Clean {
		_ = os.RemoveAll(orgHome)
	}

	if err := os.MkdirAll(orgHome, 0o755); err != nil {
		return err
	}
	if err := os.MkdirAll(tlscaClientHome, 0o755); err != nil {
		return err
	}

	// CA admin enroll -> orgHome/msp
	if err := client.Enroll(fabricca.EnrollRequest{
		CAName:      cfg.CA.Name,
		Port:        cfg.CA.Port,
		TLSCertFile: cfg.CA.TLSCert,
		ClientHome:  orgHome,
		User:        cfg.CA.AdminUser,
		Pass:        cfg.CA.AdminPass,
		MSPDir:      filepath.Join(orgHome, "msp"),
	}); err != nil {
		return fmt.Errorf("enroll CA admin: %w", err)
	}

	if err := EnsureNodeOUsConfig(orgHome); err != nil {
		return fmt.Errorf("write NodeOUs config: %w", err)
	}

	// Register on CA
	for _, id := range cfg.RegisterOnCA {
		if err := client.Register(fabricca.RegisterRequest{
			CAName:      cfg.CA.Name,
			Port:        cfg.CA.Port,
			TLSCertFile: cfg.CA.TLSCert,
			ClientHome:  orgHome,
			Name:        id.Name,
			Secret:      id.Secret,
			Type:        id.Type,
			Idempotent:  true,
		}); err != nil {
			return fmt.Errorf("register on CA (%s): %w", id.Name, err)
		}
	}

	ordererSecret, ok := findSecret(cfg.RegisterOnCA, cfg.Orderer)
	if !ok {
		return fmt.Errorf("orderer identity %q not found in --id list", cfg.Orderer)
	}

	// Enroll orderer MSP
	ordererMSPDir := filepath.Join(orgHome, "orderers", ordererFQDN, "msp")
	if err := client.Enroll(fabricca.EnrollRequest{
		CAName:      cfg.CA.Name,
		Port:        cfg.CA.Port,
		TLSCertFile: cfg.CA.TLSCert,
		ClientHome:  orgHome,
		User:        cfg.Orderer,
		Pass:        ordererSecret,
		MSPDir:      ordererMSPDir,
		CSRHosts:    []string{ordererFQDN},
	}); err != nil {
		return fmt.Errorf("enroll orderer MSP: %w", err)
	}
	if err := util.CopyFile(filepath.Join(orgHome, "msp", "config.yaml"), filepath.Join(ordererMSPDir, "config.yaml")); err != nil {
		return err
	}

	// TLSCA admin enroll -> tlscaClientHome/msp
	if err := client.Enroll(fabricca.EnrollRequest{
		CAName:      cfg.TLSCA.Name,
		Port:        cfg.TLSCA.Port,
		TLSCertFile: cfg.TLSCA.TLSCert,
		ClientHome:  tlscaClientHome,
		User:        cfg.TLSCA.AdminUser,
		Pass:        cfg.TLSCA.AdminPass,
		MSPDir:      filepath.Join(tlscaClientHome, "msp"),
	}); err != nil {
		return fmt.Errorf("enroll TLSCA admin: %w", err)
	}

	// Register on TLSCA
	for _, id := range cfg.RegisterOnTLSCA {
		if err := client.Register(fabricca.RegisterRequest{
			CAName:      cfg.TLSCA.Name,
			Port:        cfg.TLSCA.Port,
			TLSCertFile: cfg.TLSCA.TLSCert,
			ClientHome:  tlscaClientHome,
			Name:        id.Name,
			Secret:      id.Secret,
			Type:        id.Type,
			Idempotent:  true,
		}); err != nil {
			return fmt.Errorf("register on TLSCA (%s): %w", id.Name, err)
		}
	}

	// Enroll orderer TLS
	ordererTLSDir := filepath.Join(orgHome, "orderers", ordererFQDN, "tls")
	if err := client.Enroll(fabricca.EnrollRequest{
		CAName:      cfg.TLSCA.Name,
		Port:        cfg.TLSCA.Port,
		TLSCertFile: cfg.TLSCA.TLSCert,
		ClientHome:  orgHome,
		User:        cfg.Orderer,
		Pass:        ordererSecret,
		MSPDir:      ordererTLSDir,
		Profile:     "tls",
		CSRHosts:    []string{ordererFQDN, "localhost"},
	}); err != nil {
		return fmt.Errorf("enroll orderer TLS: %w", err)
	}
	if err := StandardizeTLSFilenames(ordererTLSDir); err != nil {
		return fmt.Errorf("standardize orderer TLS filenames: %w", err)
	}

	_ = os.MkdirAll(filepath.Join(orgHome, "msp", "tlscacerts"), 0o755)
	_ = util.CopyFile(filepath.Join(ordererTLSDir, "ca.crt"), filepath.Join(orgHome, "msp", "tlscacerts", "ca.crt"))

	// Enroll orderer admin MSP
	adminName := "ordereradmin"
	adminSecret, ok := findSecret(cfg.RegisterOnCA, adminName)
	if !ok {
		return fmt.Errorf("orderer admin identity %q not found in --id list", adminName)
	}
	adminMSPDir := filepath.Join(orgHome, "users", fmt.Sprintf("Admin@%s", cfg.Domain), "msp")
	if err := client.Enroll(fabricca.EnrollRequest{
		CAName:      cfg.CA.Name,
		Port:        cfg.CA.Port,
		TLSCertFile: cfg.CA.TLSCert,
		ClientHome:  orgHome,
		User:        adminName,
		Pass:        adminSecret,
		MSPDir:      adminMSPDir,
	}); err != nil {
		return fmt.Errorf("enroll orderer admin MSP: %w", err)
	}
	_ = util.CopyFile(filepath.Join(orgHome, "msp", "config.yaml"), filepath.Join(adminMSPDir, "config.yaml"))

	// Enroll orderer admin TLS (osnadmin mTLS)
	if cfg.EnrollAdminTLS {
		adminTLSDir := filepath.Join(orgHome, "users", fmt.Sprintf("Admin@%s", cfg.Domain), "tls")
		if err := client.Enroll(fabricca.EnrollRequest{
			CAName:      cfg.TLSCA.Name,
			Port:        cfg.TLSCA.Port,
			TLSCertFile: cfg.TLSCA.TLSCert,
			ClientHome:  orgHome,
			User:        adminName,
			Pass:        adminSecret,
			MSPDir:      adminTLSDir,
			Profile:     "tls",
			CSRHosts:    []string{fmt.Sprintf("Admin@%s", cfg.Domain), "localhost"},
		}); err != nil {
			return fmt.Errorf("enroll orderer admin TLS: %w", err)
		}
		if err := StandardizeClientTLSFilenames(adminTLSDir); err != nil {
			return fmt.Errorf("standardize orderer admin TLS filenames: %w", err)
		}
	}

	return nil
}
