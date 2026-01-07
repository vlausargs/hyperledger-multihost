#!/usr/bin/env bash
mkdir -p "$HOME/hlf-tools"
cd "$HOME/hlf-tools"

# Fabric LTS line (v2.5.x) example:
FABRIC_VERSION=2.5.14
FABRIC_CA_VERSION=1.5.16

curl -sSL https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh \
  | bash -s -- -f "${FABRIC_VERSION}" -c "${FABRIC_CA_VERSION}" b d
