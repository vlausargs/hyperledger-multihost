package fabricca

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

type Client struct {
	Bin string
}

func NewClient(bin string) *Client {
	return &Client{Bin: bin}
}

type RegisterRequest struct {
	CAName      string
	Port        int
	TLSCertFile string
	ClientHome  string

	Name   string
	Secret string
	Type   string

	Idempotent bool
}

type EnrollRequest struct {
	CAName      string
	Port        int
	TLSCertFile string
	ClientHome  string

	User   string
	Pass   string
	MSPDir string

	Profile  string
	CSRHosts []string
}

func (c *Client) Register(req RegisterRequest) error {
	args := []string{
		"register",
		"--caname", req.CAName,
		"--id.name", req.Name,
		"--id.secret", req.Secret,
		"--id.type", req.Type,
		"--tls.certfiles", req.TLSCertFile,
	}
	out, err := c.run(req.ClientHome, req.Port, args)
	if err == nil {
		return nil
	}

	// Idempotency: treat "already registered" as success (matches your bash behavior).
	if req.Idempotent && strings.Contains(strings.ToLower(out), "already registered") {
		return nil
	}
	return fmt.Errorf("fabric-ca-client register failed: %w\n%s", err, out)
}

func (c *Client) Enroll(req EnrollRequest) error {
	url := fmt.Sprintf("https://%s:%s@localhost:%d", req.User, req.Pass, req.Port)
	args := []string{
		"enroll",
		"-u", url,
		"--caname", req.CAName,
		"-M", req.MSPDir,
		"--tls.certfiles", req.TLSCertFile,
	}
	if strings.TrimSpace(req.Profile) != "" {
		args = append(args, "--enrollment.profile", req.Profile)
	}
	for _, h := range req.CSRHosts {
		args = append(args, "--csr.hosts", h)
	}

	out, err := c.run(req.ClientHome, req.Port, args)
	if err != nil {
		return fmt.Errorf("fabric-ca-client enroll failed: %w\n%s", err, out)
	}
	return nil
}

func (c *Client) run(clientHome string, _ int, args []string) (string, error) {
	// 60s is usually enough for local CA; adjust if you want.
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, c.Bin, args...)
	cmd.Env = append(cmd.Environ(), "FABRIC_CA_CLIENT_HOME="+clientHome)

	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf

	err := cmd.Run()
	out := buf.String()

	if ctx.Err() == context.DeadlineExceeded {
		return out, fmt.Errorf("command timeout: %s %s", c.Bin, strings.Join(args, " "))
	}
	return out, err
}
