# Compose EVM Simplified

This repository contains all the resources for deploying a forger or rpc EVM sidechain node on mainnet or testnet.

## Requirements

* docker
* docker compose v2
* jq
* pwgen
* gnu-sed for Darwin distributions

---

## Deployment

1. [Rpc node](./docs/RPC.md)
2. [Forger node](./docs/FORGER.md)

---

## Upgrade

1. Run the [upgrade.sh](./scripts/upgrade.sh) script to upgrade the project to the new version. Should the script prompt you to update some of the values in .env file, it is recommended to accept all the changes unless you know what you are doing.
2. Check that you're running the updated versions with the following commands:
```
# check that the containers are running the correct versions
docker ps

# check the EVMAPP version
docker exec evmapp gosu user curl -X POST "http://127.0.0.1:9545/node/info" -H  "accept: application/json" | grep nodeVersion

# check the ZEND version
docker exec zend gosu user zen-cli getinfo | grep version
```

# Migration from version 1.2.0

(Only for projects that are using version 1.2.0 or earlier)

1. If your project structure is 1.2.* , first follow the instructions here: [Migration from 1.2.* to 1.3.0](./docs/MIGRATION.md)

---

