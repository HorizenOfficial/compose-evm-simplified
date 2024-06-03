# Forger Node

## Setup

Run the init.sh script to initialize the deployment for the first time. Select **forger** node and the **network** to run (eon or gobi).

```shell
./scripts/init.sh
```

The script will generate the required deployment files under the [deployments](../deployments) directory and provide instructions on how to run the compose stack.

--- 

## Zend seed

A forger node requires a zend node to be running as well. Syncing a zend node from scratch may take a few hours,
therefore a seed file can be used to speed up the process.

On start up, the zend node will run the [seed.sh](../scripts/forger/seed/seed.sh) script to check if the seed process is required.

The script will be run if the following conditions are met:

- If **blocks** and **chainstate** directories exists in the **seed** directory and are not empty, the script will attempt to run the seed process.
- If **blocks** or **chainstate** directories or the **.seed.complete** file exist in the node's datadir, the seed process will not be run.
- If `ZEN_FORCE_RESEED` is set to `true` in the `deployments/forger/[eon|gobi]/.env` file, the seed process will be run regardless of the previous condition 
(this will remove the **.seed.complete** file and **blocks** and **chainstate** directories, and force the seed process to be run)

Once the seed process has been run successfully at least once a **.seed.complete** file will be created in the seed directory to prevent the seed process to be run again.

The **blocks** and **chainstate** directories can be added to the `deployments/forger/[eon|gobi]/seed` directory either manually or running the [download_seed.sh](../scripts/forger/seed/download_seed.sh) script.
This directory will be mounted into the zend container and used to seed the node.

### Manually

- Find the seed file url in `deployments/forger/[eon|gobi]/.env` file under the `ZEN_SEED_TAR_GZ_URL` variable.
- Download the seed file and extract it into the `deployments/forger/[eon|gobi]/seed` directory.

### Using the download_seed.sh script

- Run the following command to download and extract the seed file into `deployments/forger/[eon|gobi]/seed` directory:
    ```shell
    ./deployments/forger/[eon|gobi]/scripts/download_seed.sh
    ```

--- 

## Running the stack

1. Prerequisites
    - Storage: A minimum of **250 GB** of free space is required to run evmapp and zend nodes in mainnet and around **25 GB** in testnet. 
   Keep in mind that the storage requirements will grow over time.

2. Run the zend node and let it sync (only required the first time the stack is started):
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml up -d zend
    ```

3. Verify if zend node is fully synced by running the following command and comparing the output with the current block height in the mainchain: https://explorer.horizen.io or https://explorer-testnet.horizen.io:
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml exec zend gosu user zen-cli getblockcount
    ```

4. Once the zend node is fully synced, run the evmapp node:
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml up -d
    ```
   
5. Verify if the evmapp node is fully synced by running the following command and comparing the output with the current block height in the sidechain: https://eon-explorer.horizenlabs.io or https://gobi-explorer.horizenlabs.io:
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml exec evmapp gosu user bash -c 'curl -sXPOST "http://127.0.0.1:${SCNODE_REST_PORT}/block/best" -H "accept: application/json" | jq '.result.height''
    ```

6. Once the evmapp node is fully synced, generate the keys required to run a forger node:
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

7. **STORE THESE VALUES IN A SAFE PLACE. THESE VALUES WILL BE REQUIRED IN THE STAKING PROCESS**

8. Verify that the keys were generated correctly by running the following command:
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml exec evmapp gosu user bash -c 'curl -sXPOST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/allPublicKeys" -H "accept: application/json" -H "Content-Type: application/json"'
    ```

9. **IMPORTANT NOTE**
   - The address  **_"Generated Ethereum Address Key Pair"_** is where rewards will go to. 
   - Rewards are paid to the address specified in the .env file if it is not empty; otherwise, they are paid to the first ETH address in the Forger Node's wallet. 
   - **We recommend not to delegate from the node so that no stakes have to be custodied on it, which reduces attack surface.**
   - Stakes should be delegated from web3 wallets like MetaMask. 
   - You can also import this address into MetaMask as an external account so that you can spend the rewards without having to use the node's api.

10. Registration Step for the Forger: will be performed by executing a transaction declaring the forger public keys (VRF key and block sign key), 
    the percentage of rewards to be redirected to a smart contract responsible to manage the delegators’ rewards (named “reward share”), 
    and the address of that smart contract. (The last two fields will be optional).
    An additional signature will be required with the method to prove that the sender is the effective owner of the forger keys, 
    for this reason the preferred way is to use the new http endpoint `/transaction/registerForger` 
    to invoke the tx based on the local wallet data (it will handle automatically the additional signature).
    A minimum amount of **10 ZEN** will be required to be sent with the transaction, it will be converted automatically 
    into the first stake assigned to the forger. For more information about the registration process, please refer to the 
    [EVM documentation](https://github.com/HorizenOfficial/eon/blob/1.4.0-RC1/doc/api/transaction/registerForger.md).
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml exec evmapp gosu user bash -c 'curl -sXPOST "http://127.0.0.1:${SCNODE_REST_PORT}/transaction/registerForger" -H "accept: application/json" -d <requestBody>'
    
    # Request body example:
    {
       "blockSignPubKey": "10e9b5236a56cddb9f0332e9dd6d69151494f24172b26ab24a27473bbc92a181",
       "vrfPubKey": "6a376f8a88b386f69296baa0792641d393c85a19b28dfd4a11d8f0a74618873280",
       "rewardShare": "234",
       "rewardAddress": "62b1bc6fd237b775138d910274ff2911d7aea5cc",      
       "stakedAmount": "100000000000",   
    }
    ```

11. **IMPORTANT NOTE 2**
    - The registration step will not be required for existing forgers owning a stake before the hard fork. These will be 
    automatically added to the list of registered ones, with "reward share" = 0 and "smart contract address" = none.
    - Another http endpoint `/transaction/updateForger` has been added to update existing forgers [updateForger](https://github.com/HorizenOfficial/eon/blob/1.4.0-RC1/doc/api/transaction/updateForger.md) in order to allow forgers with 
    "reward share" = 0 and "smart contract address" = none to update the fields. The update will be allowed only one time, once set, the values will be immutable.
    This protects delegators from distribution mechanisms being changed without their knowledge.
    - The consensus lottery will consider only forgers owning an amount of stakes (directly or delegated) equal or over **10 ZEN**.


---

## Import or Restart a Forger Node With Existing Keys

In order to import or restart a forger node with existing keys, it is important to generate the keys before the node starts syncing.

Please follow these steps:
1. Follow Steps 1-3 from the previous section to start the zend node and let it sync. When requested by init.sh script provide the same `wallet seed phrase` used to generate the keys.
2. Prepare the evmapp node to run without peers or connection. This will allow the node to generate the keys before syncing. To achieve this edit the docker-compose.yml file and comment out the inet network on evmapp service:
   ```yaml
      evmapp:
        image: "zencash/evmapp:${EVMAPP_TAG}"
        container_name: "${EVMAPP_CONTAINER_NAME:-evmapp}"
        restart: on-failure:5
        stop_grace_period: 10m
        networks:
          evmapp_network:
            ipv4_address: ${EVMAPP_IP_ADDRESS}
          # inet:

    ```
3. Run the evmapp node:
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml up -d evmapp
    ```
4. Follow steps 6-9 from the previous section to generate the keys. This will generate exactly the same keys, as the wallet seed phrase is the same.
5. Stop the evmapp node:
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml stop evmapp
    ```
6. Undo the changes made in step 2.
7. Run the evmapp node:
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml up -d evmapp --force-recreate
    ```
8. Verify if the evmapp node is fully synced by running the following command and comparing the output with the current block height in the sidechain: https://eon-explorer.horizenlabs.io or https://gobi-explorer.horizenlabs.io:
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml exec evmapp gosu user bash -c 'curl -sXPOST "http://127.0.0.1:${SCNODE_REST_PORT}/block/best" -H "accept: application/json" | jq '.result.height''
    ```

--- 

## Other useful docker commands

- Run the following command to stop the stack:
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml stop
    ```
- Run the following command to start the stack again:
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml up -d
    ```
- Run the following command to stop the stack and delete the containers:
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml down
    ```
- Run the following commands to destroy the stack, **this action will delete your wallet and all the data**:
    ```shell
    docker compose -f deployments/forger/[eon|gobi]/docker-compose.yml down
    docker volume ls # List all the volumes
    docker volume rm [volume_name] # Remove the volumes related to your stack, these volumes are named after the stack name: [COMPOSE_PROJECT_NAME]_[volume-name]
    ```

---

## Staking

To participate in staking on EON, use the [eon-smart-contract-tools](https://github.com/HorizenOfficial/eon-smart-contract-tools) to create a Forging Stake using Web3.js.

---
