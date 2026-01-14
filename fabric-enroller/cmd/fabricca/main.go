package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"fabric-enroller/internal/enroll"
	"fabric-enroller/internal/fabricca"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	switch os.Args[1] {
	case "enroll-org":
		cmdEnrollOrg(os.Args[2:])
	case "enroll-orderer":
		cmdEnrollOrderer(os.Args[2:])
	case "register":
		cmdRegister(os.Args[2:])
	case "enroll":
		cmdEnroll(os.Args[2:])
	case "enroll-user":
		cmdEnrollUser(os.Args[2:])
	default:
		usage()
		os.Exit(2)
	}
}

func usage() {
	fmt.Fprintf(os.Stderr, `fabric-enroller - Hyperledger Fabric CA enrollment helper

Commands:
  enroll-org		Full org bootstrap (CA admin enroll, register ids, peer MSP+TLS, org admin MSP)
  enroll-orderer	Full orderer bootstrap (CA admin enroll, register ids, orderer MSP+TLS, orderer admin MSP+TLS)
  register			Register an identity (idempotent)
  enroll			Enroll an identity into an MSP/TLS directory
  enroll-user		Convenience: register+enroll a client/admin user into organizations/.../users/...

Examples:
  # Full org (similar to your script)
  fabric-enroller enroll-org \
    --root-dir /path/to/fabric-2pc-3org-template \
    --org org1 --domain example.com \
    --ca-port 7054 --tlsca-port 7055 \
    --ca-name ca-org1 --tlsca-name tlsca-org1

  # Full orderer (similar to your 06-enroll-orderer.sh)
  fabric-enroller enroll-orderer \
    --root-dir /path/to/fabric-2pc-3org-template \
    --domain example.com \
    --ca-port 9054 --tlsca-port 9055 \
    --ca-name ca-orderer --tlsca-name tlsca-orderer

  # Add a new client user (register + enroll)
  fabric-enroller enroll-user \
    --root-dir /path/to/fabric-2pc-3org-template \
    --org org1 --domain example.com \
    --ca-port 7054 --ca-name ca-org1 \
    --ca-tls-cert organizations/fabric-ca/org1/ca/tls-cert.pem \
    --user user2 --secret user2pw --type client

Notes:
  - This tool shells out to 'fabric-ca-client' and requires it in PATH.
  - It uses FABRIC_CA_CLIENT_HOME per call (same concept as your bash script).
`)
}

type idSpecList []string

func (l *idSpecList) String() string { return strings.Join(*l, ",") }
func (l *idSpecList) Set(v string) error {
	*l = append(*l, v)
	return nil
}

// format: name:secret:type  (e.g. peer0:peer0pw:peer)
func parseIDSpec(s string) (name, secret, typ string, err error) {
	parts := strings.Split(s, ":")
	if len(parts) != 3 {
		return "", "", "", fmt.Errorf("invalid --id %q; expected name:secret:type", s)
	}
	return parts[0], parts[1], parts[2], nil
}

func cmdEnrollOrg(args []string) {
	fs := flag.NewFlagSet("enroll-org", flag.ExitOnError)

	rootDir := fs.String("root-dir", "", "Root directory of your fabric project (contains organizations/)")
	org := fs.String("org", "", "Org name, e.g. org1")
	domain := fs.String("domain", "", "Domain, e.g. example.com")
	peer := fs.String("peer", "peer0", "Peer name, e.g. peer0")
	clean := fs.Bool("clean", true, "Remove existing org home before enrolling (idempotent rerun)")
	fixPerms := fs.Bool("fix-perms", false, "Attempt to chown organizations/ recursively to current user (may require root)")

	caPort := fs.Int("ca-port", 0, "CA port, e.g. 7054")
	tlscaPort := fs.Int("tlsca-port", 0, "TLSCA port, e.g. 7055")
	caName := fs.String("ca-name", "", "CA name, e.g. ca-org1")
	tlscaName := fs.String("tlsca-name", "", "TLSCA name, e.g. tlsca-org1")

	caAdminUser := fs.String("ca-admin-user", "admin", "CA admin user")
	caAdminPass := fs.String("ca-admin-pass", "adminpw", "CA admin password")
	tlscaAdminUser := fs.String("tlsca-admin-user", "admin", "TLSCA admin user")
	tlscaAdminPass := fs.String("tlsca-admin-pass", "adminpw", "TLSCA admin password")

	caTLSCert := fs.String("ca-tls-cert", "", "Path to CA tls-cert.pem")
	tlscaTLSCert := fs.String("tlsca-tls-cert", "", "Path to TLSCA tls-cert.pem")

	var ids idSpecList
	fs.Var(&ids, "id", "Identity to register on CA: name:secret:type (repeatable). Defaults: peer0/orgAdmin/user1")

	if err := fs.Parse(args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}

	if *rootDir == "" {
		wd, _ := os.Getwd()
		*rootDir = wd
	}
	absRoot, _ := filepath.Abs(*rootDir)

	// Provide sensible defaults matching your current file layout if not specified.
	if *org == "" || *domain == "" {
		fmt.Fprintln(os.Stderr, "--org and --domain are required")
		os.Exit(2)
	}
	if *caPort == 0 || *tlscaPort == 0 {
		fmt.Fprintln(os.Stderr, "--ca-port and --tlsca-port are required")
		os.Exit(2)
	}
	if *caName == "" || *tlscaName == "" {
		fmt.Fprintln(os.Stderr, "--ca-name and --tlsca-name are required")
		os.Exit(2)
	}
	if *caTLSCert == "" {
		*caTLSCert = filepath.Join(absRoot, "organizations", "fabric-ca", *org, "ca", "tls-cert.pem")
	}
	if *tlscaTLSCert == "" {
		*tlscaTLSCert = filepath.Join(absRoot, "organizations", "fabric-ca", *org, "tlsca", "tls-cert.pem")
	}

	// Default identities if user didn't specify any.
	if len(ids) == 0 {
		// peer identity name is peer name without domain, typically "peer0"
		orgAdmin := fmt.Sprintf("%sadmin", *org) // matches your script pattern (org1admin)
		ids = append(ids,
			fmt.Sprintf("%s:%spw:peer", *peer, *peer),
			fmt.Sprintf("%s:%spw:admin", orgAdmin, orgAdmin),
			"user1:user1pw:client",
		)
	}

	cfg := enroll.EnrollOrgConfig{
		RootDir:  absRoot,
		Org:      *org,
		Domain:   *domain,
		Peer:     *peer,
		Clean:    *clean,
		FixPerms: *fixPerms,

		CA: enroll.CAConfig{
			Port:      *caPort,
			Name:      *caName,
			TLSCert:   *caTLSCert,
			AdminUser: *caAdminUser,
			AdminPass: *caAdminPass,
		},
		TLSCA: enroll.CAConfig{
			Port:      *tlscaPort,
			Name:      *tlscaName,
			TLSCert:   *tlscaTLSCert,
			AdminUser: *tlscaAdminUser,
			AdminPass: *tlscaAdminPass,
		},
	}

	for _, spec := range ids {
		n, s, t, err := parseIDSpec(spec)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(2)
		}
		cfg.RegisterOnCA = append(cfg.RegisterOnCA, enroll.IdentitySpec{Name: n, Secret: s, Type: t})
	}

	client := fabricca.NewClient("fabric-ca-client")
	if err := enroll.RunEnrollOrg(cfg, client); err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
}

func cmdEnrollOrderer(args []string) {
	fs := flag.NewFlagSet("enroll-orderer", flag.ExitOnError)

	rootDir := fs.String("root-dir", "", "Root directory of your fabric project (contains organizations/)")
	domain := fs.String("domain", "", "Domain, e.g. example.com")
	orderer := fs.String("orderer", "orderer", "Orderer name, e.g. orderer")
	clean := fs.Bool("clean", true, "Remove existing orderer org home before enrolling (idempotent rerun)")
	fixPerms := fs.Bool("fix-perms", false, "Attempt to chown organizations/ recursively to current user (may require root)")
	enrollAdminTLS := fs.Bool("enroll-admin-tls", true, "Also enroll orderer admin TLS for osnadmin mTLS")

	caPort := fs.Int("ca-port", 0, "Orderer CA port, e.g. 9054")
	tlscaPort := fs.Int("tlsca-port", 0, "Orderer TLSCA port, e.g. 9055")
	caName := fs.String("ca-name", "", "Orderer CA name, e.g. ca-orderer")
	tlscaName := fs.String("tlsca-name", "", "Orderer TLSCA name, e.g. tlsca-orderer")

	caAdminUser := fs.String("ca-admin-user", "admin", "CA admin user")
	caAdminPass := fs.String("ca-admin-pass", "adminpw", "CA admin password")
	tlscaAdminUser := fs.String("tlsca-admin-user", "admin", "TLSCA admin user")
	tlscaAdminPass := fs.String("tlsca-admin-pass", "adminpw", "TLSCA admin password")

	caTLSCert := fs.String("ca-tls-cert", "", "Path to Orderer CA tls-cert.pem")
	tlscaTLSCert := fs.String("tlsca-tls-cert", "", "Path to Orderer TLSCA tls-cert.pem")

	var ids idSpecList
	fs.Var(&ids, "id", "Identity to register on CA and TLSCA: name:secret:type (repeatable). Defaults: orderer/ordereradmin")

	if err := fs.Parse(args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}

	if *rootDir == "" {
		wd, _ := os.Getwd()
		*rootDir = wd
	}
	absRoot, _ := filepath.Abs(*rootDir)

	if *domain == "" {
		fmt.Fprintln(os.Stderr, "--domain is required")
		os.Exit(2)
	}
	if *caPort == 0 || *tlscaPort == 0 {
		fmt.Fprintln(os.Stderr, "--ca-port and --tlsca-port are required")
		os.Exit(2)
	}
	if *caName == "" || *tlscaName == "" {
		fmt.Fprintln(os.Stderr, "--ca-name and --tlsca-name are required")
		os.Exit(2)
	}

	// Default cert locations for orderer CA/TLSCA.
	if *caTLSCert == "" {
		*caTLSCert = filepath.Join(absRoot, "organizations", "fabric-ca", "orderer", "ca", "tls-cert.pem")
	}
	if *tlscaTLSCert == "" {
		*tlscaTLSCert = filepath.Join(absRoot, "organizations", "fabric-ca", "orderer", "tlsca", "tls-cert.pem")
	}

	// Default identities if user didn't specify any.
	if len(ids) == 0 {
		ids = append(ids,
			fmt.Sprintf("%s:%spw:orderer", *orderer, *orderer),
			"ordereradmin:ordereradminpw:admin",
		)
	}

	cfg := enroll.EnrollOrdererConfig{
		RootDir:  absRoot,
		Domain:   *domain,
		Orderer:  *orderer,
		Clean:    *clean,
		FixPerms: *fixPerms,

		EnrollAdminTLS: *enrollAdminTLS,

		CA: enroll.CAConfig{
			Port:      *caPort,
			Name:      *caName,
			TLSCert:   *caTLSCert,
			AdminUser: *caAdminUser,
			AdminPass: *caAdminPass,
		},
		TLSCA: enroll.CAConfig{
			Port:      *tlscaPort,
			Name:      *tlscaName,
			TLSCert:   *tlscaTLSCert,
			AdminUser: *tlscaAdminUser,
			AdminPass: *tlscaAdminPass,
		},
	}

	for _, spec := range ids {
		n, s, t, err := parseIDSpec(spec)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(2)
		}
		cfg.RegisterOnCA = append(cfg.RegisterOnCA, enroll.IdentitySpec{Name: n, Secret: s, Type: t})
		cfg.RegisterOnTLSCA = append(cfg.RegisterOnTLSCA, enroll.IdentitySpec{Name: n, Secret: s, Type: t})
	}

	client := fabricca.NewClient("fabric-ca-client")
	if err := enroll.RunEnrollOrderer(cfg, client); err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
}

func cmdRegister(args []string) {
	fs := flag.NewFlagSet("register", flag.ExitOnError)

	caname := fs.String("caname", "", "CA name")
	port := fs.Int("port", 0, "CA port")
	tlsCert := fs.String("tls-cert", "", "CA tls-cert.pem path")
	clientHome := fs.String("client-home", "", "FABRIC_CA_CLIENT_HOME directory")

	name := fs.String("name", "", "Identity name")
	secret := fs.String("secret", "", "Identity secret")
	typ := fs.String("type", "", "Identity type: client|peer|admin|orderer")

	if err := fs.Parse(args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}

	if *caname == "" || *port == 0 || *tlsCert == "" || *clientHome == "" || *name == "" || *secret == "" || *typ == "" {
		fmt.Fprintln(os.Stderr, "missing required flags; see -h")
		os.Exit(2)
	}

	client := fabricca.NewClient("fabric-ca-client")
	err := client.Register(fabricca.RegisterRequest{
		CAName:      *caname,
		Port:        *port,
		TLSCertFile: *tlsCert,
		ClientHome:  *clientHome,
		Name:        *name,
		Secret:      *secret,
		Type:        *typ,
		Idempotent:  true,
	})
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
}

func cmdEnroll(args []string) {
	fs := flag.NewFlagSet("enroll", flag.ExitOnError)

	caname := fs.String("caname", "", "CA name")
	port := fs.Int("port", 0, "CA port")
	tlsCert := fs.String("tls-cert", "", "CA tls-cert.pem path")
	clientHome := fs.String("client-home", "", "FABRIC_CA_CLIENT_HOME directory")

	user := fs.String("user", "", "Enrollment user (id.name)")
	pass := fs.String("pass", "", "Enrollment password (id.secret)")
	mspDir := fs.String("msp-dir", "", "Output MSP/TLS directory (-M)")
	profile := fs.String("profile", "", "Optional enrollment profile (e.g. tls)")
	hosts := fs.String("hosts", "", "Comma-separated CSR hosts for --csr.hosts")

	if err := fs.Parse(args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}

	if *caname == "" || *port == 0 || *tlsCert == "" || *clientHome == "" || *user == "" || *pass == "" || *mspDir == "" {
		fmt.Fprintln(os.Stderr, "missing required flags; see -h")
		os.Exit(2)
	}

	var csrHosts []string
	if strings.TrimSpace(*hosts) != "" {
		for _, h := range strings.Split(*hosts, ",") {
			h = strings.TrimSpace(h)
			if h != "" {
				csrHosts = append(csrHosts, h)
			}
		}
	}

	client := fabricca.NewClient("fabric-ca-client")
	err := client.Enroll(fabricca.EnrollRequest{
		CAName:      *caname,
		Port:        *port,
		TLSCertFile: *tlsCert,
		ClientHome:  *clientHome,
		User:        *user,
		Pass:        *pass,
		MSPDir:      *mspDir,
		Profile:     *profile,
		CSRHosts:    csrHosts,
	})
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
}

func cmdEnrollUser(args []string) {
	fs := flag.NewFlagSet("enroll-user", flag.ExitOnError)

	rootDir := fs.String("root-dir", "", "Root directory of your fabric project (contains organizations/)")
	org := fs.String("org", "", "Org name, e.g. org1")
	domain := fs.String("domain", "", "Domain, e.g. example.com")
	caPort := fs.Int("ca-port", 0, "CA port")
	caName := fs.String("ca-name", "", "CA name")
	caTLSCert := fs.String("ca-tls-cert", "", "Path to CA tls-cert.pem")

	user := fs.String("user", "", "User name to create/enroll (e.g. user2)")
	secret := fs.String("secret", "", "User secret (e.g. user2pw)")
	typ := fs.String("type", "client", "Type: client|admin")
	if err := fs.Parse(args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}

	if *rootDir == "" {
		wd, _ := os.Getwd()
		*rootDir = wd
	}
	absRoot, _ := filepath.Abs(*rootDir)

	if *org == "" || *domain == "" || *caPort == 0 || *caName == "" || *user == "" || *secret == "" {
		fmt.Fprintln(os.Stderr, "missing required flags; see -h")
		os.Exit(2)
	}
	if *caTLSCert == "" {
		*caTLSCert = filepath.Join(absRoot, "organizations", "fabric-ca", *org, "ca", "tls-cert.pem")
	}

	orgHome := filepath.Join(absRoot, "organizations", "peerOrganizations", fmt.Sprintf("%s.%s", *org, *domain))
	usersDir := filepath.Join(orgHome, "users", fmt.Sprintf("%s@%s.%s", strings.Title(*user), *org, *domain), "msp")

	client := fabricca.NewClient("fabric-ca-client")

	// Register idempotently using org CA admin context (assumes orgHome already has CA admin enrollment).
	if err := client.Register(fabricca.RegisterRequest{
		CAName:      *caName,
		Port:        *caPort,
		TLSCertFile: *caTLSCert,
		ClientHome:  orgHome,
		Name:        *user,
		Secret:      *secret,
		Type:        *typ,
		Idempotent:  true,
	}); err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}

	if err := client.Enroll(fabricca.EnrollRequest{
		CAName:      *caName,
		Port:        *caPort,
		TLSCertFile: *caTLSCert,
		ClientHome:  orgHome,
		User:        *user,
		Pass:        *secret,
		MSPDir:      usersDir,
	}); err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}

	fmt.Println("User enrollment complete:", usersDir)
}
