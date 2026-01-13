package enroll

import (
	"fmt"
	"os"
	"path/filepath"

	"fabric-enroller/internal/fabricca"
	"fabric-enroller/internal/util"
)

type CAConfig struct {
	Port      int
	Name      string
	TLSCert   string
	AdminUser string
	AdminPass string
}

type IdentitySpec struct {
	Name   string
	Secret string
	Type   string
}

type EnrollOrgConfig struct {
	RootDir string
	Org     string
	Domain  string
	Peer    string

	Clean    bool
	FixPerms bool

	CA    CAConfig
	TLSCA CAConfig

	// Registered on CA (not TLSCA). Peer should also be registered on TLSCA.
	RegisterOnCA []IdentitySpec
}

func RunEnrollOrg(cfg EnrollOrgConfig, client *fabricca.Client) error {
	orgFQDN := fmt.Sprintf("%s.%s", cfg.Org, cfg.Domain)
	peerFQDN := fmt.Sprintf("%s.%s.%s", cfg.Peer, cfg.Org, cfg.Domain)

	orgHome := filepath.Join(cfg.RootDir, "organizations", "peerOrganizations", orgFQDN)
	tlscaClientHome := filepath.Join(orgHome, ".tlsca-client")

	if cfg.FixPerms {
		// Best-effort. If you previously used sudo in scripts, you may still need sudo externally.
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

	// -----------------------------
	// CA: enroll admin
	// -----------------------------
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

	// Write NodeOUs config at org MSP root.
	if err := EnsureNodeOUsConfig(orgHome); err != nil {
		return fmt.Errorf("write NodeOUs config.yaml: %w", err)
	}

	// -----------------------------
	// CA: register identities (idempotent)
	// -----------------------------
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

	// -----------------------------
	// Peer MSP enrollment (CA)
	// -----------------------------
	peerMSPDir := filepath.Join(orgHome, "peers", peerFQDN, "msp")
	peerSecret, ok := findSecret(cfg.RegisterOnCA, cfg.Peer)
	if !ok {
		return fmt.Errorf("peer identity %q not found in --id list; include %s:<pw>:peer", cfg.Peer, cfg.Peer)
	}

	if err := client.Enroll(fabricca.EnrollRequest{
		CAName:      cfg.CA.Name,
		Port:        cfg.CA.Port,
		TLSCertFile: cfg.CA.TLSCert,
		ClientHome:  orgHome,
		User:        cfg.Peer,
		Pass:        peerSecret,
		MSPDir:      peerMSPDir,
		CSRHosts:    []string{peerFQDN},
	}); err != nil {
		return fmt.Errorf("enroll peer MSP: %w", err)
	}

	// Copy NodeOUs config into peer MSP.
	if err := util.CopyFile(filepath.Join(orgHome, "msp", "config.yaml"), filepath.Join(peerMSPDir, "config.yaml")); err != nil {
		return fmt.Errorf("copy peer MSP config.yaml: %w", err)
	}

	// -----------------------------
	// TLSCA: enroll admin using separate client home
	// -----------------------------
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

	// TLSCA: register peer (idempotent)
	if err := client.Register(fabricca.RegisterRequest{
		CAName:      cfg.TLSCA.Name,
		Port:        cfg.TLSCA.Port,
		TLSCertFile: cfg.TLSCA.TLSCert,
		ClientHome:  tlscaClientHome,
		Name:        cfg.Peer,
		Secret:      peerSecret,
		Type:        "peer",
		Idempotent:  true,
	}); err != nil {
		return fmt.Errorf("register peer on TLSCA: %w", err)
	}

	// -----------------------------
	// Peer TLS enrollment (TLSCA) into orgHome paths
	// -----------------------------
	peerTLSDir := filepath.Join(orgHome, "peers", peerFQDN, "tls")
	if err := client.Enroll(fabricca.EnrollRequest{
		CAName:      cfg.TLSCA.Name,
		Port:        cfg.TLSCA.Port,
		TLSCertFile: cfg.TLSCA.TLSCert,
		ClientHome:  orgHome, // write TLS material under org home layout
		User:        cfg.Peer,
		Pass:        peerSecret,
		MSPDir:      peerTLSDir,
		Profile:     "tls",
		CSRHosts:    []string{peerFQDN, "localhost"},
	}); err != nil {
		return fmt.Errorf("enroll peer TLS: %w", err)
	}

	if err := StandardizeTLSFilenames(peerTLSDir); err != nil {
		return fmt.Errorf("standardize TLS filenames: %w", err)
	}

	// org MSP tlscacerts
	if err := os.MkdirAll(filepath.Join(orgHome, "msp", "tlscacerts"), 0o755); err != nil {
		return err
	}
	if err := util.CopyFile(filepath.Join(peerTLSDir, "ca.crt"), filepath.Join(orgHome, "msp", "tlscacerts", "ca.crt")); err != nil {
		return err
	}

	// -----------------------------
	// Org admin MSP enrollment (CA)
	// -----------------------------
	orgAdminName := fmt.Sprintf("%sadmin", cfg.Org)
	orgAdminSecret, ok := findSecret(cfg.RegisterOnCA, orgAdminName)
	if !ok {
		// If you prefer a different admin naming scheme, just include it in --id.
		return fmt.Errorf("org admin identity %q not found in --id list (example: %s:%spw:admin)", orgAdminName, orgAdminName, orgAdminName)
	}
	adminMSPDir := filepath.Join(orgHome, "users", fmt.Sprintf("Admin@%s.%s", cfg.Org, cfg.Domain), "msp")

	if err := client.Enroll(fabricca.EnrollRequest{
		CAName:      cfg.CA.Name,
		Port:        cfg.CA.Port,
		TLSCertFile: cfg.CA.TLSCert,
		ClientHome:  orgHome,
		User:        orgAdminName,
		Pass:        orgAdminSecret,
		MSPDir:      adminMSPDir,
	}); err != nil {
		return fmt.Errorf("enroll org admin MSP: %w", err)
	}

	if err := util.CopyFile(filepath.Join(orgHome, "msp", "config.yaml"), filepath.Join(adminMSPDir, "config.yaml")); err != nil {
		return fmt.Errorf("copy admin MSP config.yaml: %w", err)
	}

	// Quick check similar to `ls -lah tlsdir`
	entries, _ := os.ReadDir(peerTLSDir)
	fmt.Printf("Enrollment complete. Peer TLS dir: %s\n", peerTLSDir)
	for _, e := range entries {
		info, _ := e.Info()
		if info != nil {
			fmt.Printf("  %s (%d bytes)\n", e.Name(), info.Size())
		}
	}
	return nil
}

func findSecret(ids []IdentitySpec, name string) (string, bool) {
	for _, id := range ids {
		if id.Name == name {
			return id.Secret, true
		}
	}
	return "", false
}
