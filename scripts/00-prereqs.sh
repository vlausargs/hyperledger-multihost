#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/00-env.sh"

echo "Checking required binaries..."
require_cmd docker
require_cmd peer
require_cmd osnadmin
require_cmd configtxgen
require_cmd fabric-ca-client

echo "OK."
