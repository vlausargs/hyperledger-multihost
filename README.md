# Fabric 2.5 LTS - 3 Orgs / 2 Laptops Template (Fabric CA)

Topology:
- Laptop1 (192.168.7.111): Org1 CA+TLSCA + peer0.org1
- Laptop2 (192.168.7.112): Orderer CA+TLSCA + orderer + Org2 CA+TLSCA + peer0.org2 + Org3 CA+TLSCA + peer0.org3

## 0) Prereqs (both laptops)
1) Install Docker + Docker Compose v2
2) Install Fabric binaries and CA client on both laptops using Hyperledger Fabric install docs:
   - needs: peer, orderer, osnadmin, configtxgen, fabric-ca-client
3) Add /etc/hosts on BOTH laptops:
   192.168.7.112 orderer.example.com peer0.org2.example.com peer0.org3.example.com
   192.168.7.111 peer0.org1.example.com

## 1) Bring up (Laptop2 first)
Laptop2:
  ./scripts/prereqs.sh
  ./scripts/l2-up-ca.sh
  ./scripts/enroll-orderer.sh
  ./scripts/enroll-org2.sh
  ./scripts/enroll-org3.sh
  ./scripts/l2-up-net.sh
  ./scripts/generate-channel-artifacts.sh
  ./scripts/l2-create-channel.sh
  ./scripts/join-channel-org2.sh
  ./scripts/join-channel-org3.sh

## 2) Bring up Org1 (Laptop1)
Laptop1:
  ./scripts/prereqs.sh
  ./scripts/l1-up-ca.sh
  ./scripts/enroll-org1.sh
  ./scripts/l1-up-net.sh

Copy channel artifacts from Laptop2 -> Laptop1:
  channel-artifacts/mychannel.block
  channel-artifacts/Org1MSPanchors.tx

Then on Laptop1:
  ./scripts/join-channel-org1.sh

## 3) Deploy chaincode (2-of-3 endorsement)
Laptop2:
  ./scripts/cc-package.sh
  ./scripts/cc-install-org2.sh
  ./scripts/cc-install-org3.sh
  ./scripts/cc-approve-org2.sh
  ./scripts/cc-approve-org3.sh

Copy chaincode package asset.tar.gz from Laptop2 -> Laptop1:
  channel-artifacts/asset.tar.gz

Laptop1:
  ./scripts/cc-install-org1.sh
  ./scripts/cc-approve-org1.sh

Laptop2:
  ./scripts/cc-commit.sh
  ./scripts/cc-invoke-sample.sh
