# Compose EVM Simplified
This repo contains all the resources for deploying an EVM sidechain Node on mainnet or testnet.

---
# Deployment

### Requirements:
* docker
* docker compose v2
* bc
* jq
* pwgen

## Setup
1. Choose which network to run by moving the .env.template.network.sidechain file into a .env.

   To run mainnet EON : 
    ```shell
    cp .env.template.mainnet.eon .env
    ```
   To run testnet Gobi : 
    ```shell
    cp .env.template.testnet.gobi .env
    ```
2. Set up environment variables in the .env 
    ```shell
    SCNODE_REST_PASSWORD= # Uncomment and set this variable only if you are willing to set up authentication on the rest api endpoints
    ```
3. Run the following command to initialize and run the stack for the first time:
    ```shell
    ./scripts/init.sh
    ```
    If running for the first time, the script will prompt you to choose the type of node you would like to run (a FORGER or an RPC node).
    Please look at the "Running a Forger node" section should you want to run a Forger. 
    
    Initialization may take a considerable amount of time as it synchronizes the Horizen (ZEN) blockchain and e.g. evmapp container may
    not start within 15 minutes as zend is yet syncing. (Issue e.g. `docker compose -f docker-compose-forger.yml logs -ft --tail=10` to 
    see what's going on.)
   
4. Run the following command to stop the stack:
    ```shell
    ./scripts/stop.sh
    ```
5. Run the following command to start the stack after it was stopped:
    ```shell
    ./scripts/startup.sh
    ```

### Other useful docker commands
- Run the following command to stop the stack and delete the containers:
    ```shell
    ./scripts/shutdown.sh
    ```
- Run the following command to destroy the stack, **this action will delete your wallet and all the data**:
    ```shell
    ./scripts/clean.sh
    ```

## Usage
The evmapp node RPC interfaces will be available over HTTP at:
- http://localhost:9545/

   For example:
   ```
   curl -sX POST -H 'accept: application/json' -H 'Content-Type: application/json' "http://127.0.0.1:9545/block/best"
   ```

The Ethereum RPC interface is available at `/ethv1` location:
- http://localhost:9545/ethv1

   For example:
   ```
   curl -sX POST -H 'accept: application/json' -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}' "http://127.0.0.1:9545/ethv1"
   ```
## Notes
The RPC and WebSocket ports are only exposed locally (accessible only via localhost).
In order to expose those ports outside the local environment, you can edit the following lines in the docker-compose.yml file:
   
- Default configuration(locally exposed):
   ```
      - "127.0.0.1:${SCNODE_WS_SERVER_PORT}:${SCNODE_WS_SERVER_PORT}"
      - "127.0.0.1:${SCNODE_REST_PORT}:${SCNODE_REST_PORT}"
   ```

- Edit the lines in the following way to expose the ports externally:
   ```
      - "${SCNODE_WS_SERVER_PORT}:${SCNODE_WS_SERVER_PORT}"
      - "${SCNODE_REST_PORT}:${SCNODE_REST_PORT}"
   ```

## Running a Forger Node 

In order to run a forger node a Mainchain node is required to be running as well. This has some implications, please review the Prerequisites section.

### Prerequisites
- Storage: A minimum of 250GB of free space is required to run both nodes. Keep in mind that the storage requirements will grow over time.
- Time: Both nodes will require some time to fully synchronize the entire chains.

### Step-by-step guide ### 

1. During init.sh script run choose 'forger' when prompted. 
2. Once the EVM node ("evmapp" container) and the Mainchain node ("zend" container) are up and running, run the 'generate_forger_keys.sh' script. 
    ```shell
    ./scripts/generate_forger_keys.sh
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

3. To participate in staking on EON, use the [eon-smart-contract-tools](https://github.com/HorizenOfficial/eon-smart-contract-tools) to create a Forging Stake using Web3.js. 

    
