package util

import (
	"fmt"
	"io"
	"os"
	"os/user"
	"path/filepath"
	"strconv"
)

func CopyFile(src, dst string) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer func() { _ = out.Close() }()

	if _, err := io.Copy(out, in); err != nil {
		return err
	}
	return out.Sync()
}

// Best-effort; if not permitted, it will return an error but callers may ignore it.
func ChownRToCurrentUser(root string) error {
	u, err := user.Current()
	if err != nil {
		return err
	}
	uid, err := strconv.Atoi(u.Uid)
	if err != nil {
		return err
	}
	gid, err := strconv.Atoi(u.Gid)
	if err != nil {
		return err
	}

	return filepath.WalkDir(root, func(path string, d os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if err := os.Chown(path, uid, gid); err != nil {
			// If permissions block us, keep walking and report at end by returning nil or error.
			// Here we return error to signal failure, but caller can ignore.
			return fmt.Errorf("chown %s: %w", path, err)
		}
		return nil
	})
}
