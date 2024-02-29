# Forger Node

## Setup

--- 

Run the init.sh script to initialize the deployment for the first time. Select **forger** node and the **network** to run (eon or gobi).

```shell
./scripts/init.sh
```

The script will generate the required deployment files under the [deployments](../deployments) directory and provide instructions on how to run the compose stack.

## Zend seed

--- 

As this is a forger node, it requires a zend node to run as well. Syncing a zend node from scratch may take a few hours, 
so a seed file can be used to speed up the process.

There are two variables that help controlling the seed process for the zend node:

- `ZEN_USE_SEED_FILE`: The default value for this variable is `false`, but it can be set to true choosing to use the seed file in the init.sh script.

- `ZEN_FORCE_RESEED`: This variable is set to `false` by default, but it can be set manually to `true` if forcing the reseed of the zend node is required.

Once the zend node has been synced, the following times the stack is started there is no need to seed the zend node again.

The _seed.sh_ script will generate a **.seed.complete** file in the node's data folder, and it will prevent the seed script to be run again.

Additionally, setting the `ZEN_USE_SEED_FILE` variable to false in the .env file will prevent the seed process to be run again.

If migrating from previous versions of these project and your zend node is already synced set the `ZEN_USE_SEED_FILE` variable to false in the .env file.

If reseed of the zend node is required, set the `ZEN_FORCE_RESEED` variable to true in the .env file, and restart the stack.

## Running the stack

--- 

1. Prerequisites
    - Storage: A minimum of 250GB of free space is required to run both nodes. Keep in mind that the storage requirements will grow over time.

2. Run the zend node and let it sync (only required the first time the stack is started):
   ```shell
    cd deployments/forger/[eon|gobi] && docker compose up -d zend
    ```

3. Verify if the zend node is fully synced you can run the following command and compare the output with the current block height in the mainchain: https://explorer.horizen.io or https://explorer-testnet.horizen.io:
    ```shell
    docker exec ${ZEND_CONTAINER_NAME} gosu user curl -s --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"getblockcount\", \"params\": [] }' -H 'content-type: text/plain;' -u ${ZEN_RPC_USER]}:${ZEN_RPC_PASSWORD} http://127.0.0.1:${ZEN_RPC_PORT}/
    ```

4. Once the zend node is fully synced, run the evmapp node:
    ```shell
    cd deployments/forger/[eon|gobi] && docker compose up -d
    ```

5. Once the evmapp node is fully synced, generate the keys required to run a forger node:
    ```shell
    ./scripts/forger/generate_keys.sh
    ```

   The script will generate all the necessary keys on the local node and output the following:
    ```shell
      Generated VRF Key Pair.
      VRF Public Key         : ...
      VRF Private Key        : ...
    
      Generated Block Sign Key Pair.
      Block Sign Public Key  : ...
      Block Sign Private Key : ...
    
      Generated Ethereum Address Key Pair.
      Ethereum Address                    : ...
      Ethereum Private Key                : ...
      Ethereum Private Key for MetaMask  : ...
    ```
   **STORE THESE VALUES IN A SAFE PLACE. THESE VALUES WILL BE REQUIRED IN THE STAKING PROCESS**

   Verify that the keys were generated correctly, run the following command:
    ```shell
    docker exec ${EVMAPP_CONTAINER_NAME} gosu user curl -sXPOST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/allPublicKeys"  -H "accept: application/json" -H 'Content-Type: application/json' -d '{}'
    ```

## Other useful docker commands

--- 

- Run the following command to stop the stack:
    ```shell
    cd deployments/forger/[eon|gobi] && docker compose stop
    ```
- Run the following command to start the stack again:
    ```shell
    cd deployments/forger/[eon|gobi] && docker compose up -d
    ```
- Run the following command to stop the stack and delete the containers:
    ```shell
    cd deployments/forger/[eon|gobi] && docker compose down
    ```
- Run the following commands to destroy the stack, **this action will delete your wallet and all the data**:
    ```shell
    cd deployments/forger/[eon|gobi] && docker compose down
    docker volume ls # List all the volumes
    docker volume rm [volume_name] # Remove the volumes related to your stack, these volumes are named after the stack name: [COMPOSE_PROJECT_NAME]_[volume-name]
    ```


## Staking

---

To participate in staking on EON, use the [eon-smart-contract-tools](https://github.com/HorizenOfficial/eon-smart-contract-tools) to create a Forging Stake using Web3.js.
