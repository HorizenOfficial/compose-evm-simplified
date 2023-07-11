# Compose EVM 
This repo contains all the resources for deploying EVM sidechain on mainnet or testnet.

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
    cp .env.template.testnet.eon .env
    ```
2. Set up environment variables in the .env 
    ```shell
    SCNODE_REST_PASSWORD= # Uncomment and set this variable only if you are willing to set up authentication on the rest api endpoints
    ```
3. Run the following command to initialize and run the stack for the first time:
    ```shell
    ./scripts/init.sh
    ```
4. Run the following command to stop the stack:
    ```shell
    ./scripts/shutdown.sh
    ```
5. Run the following command to start the stack after it was stopped:
    ```shell
    ./scripts/startup.sh
    ```
6. Run the following command to destroy the stack, **this action will delete your wallet and all the data**:
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

The Ethereum RPC interface is available at /ethv1:
- http://localhost:9545/ethv1

   For example:
   ```
   curl -sX POST -H 'accept: application/json' -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}' "http://127.0.0.1:9545/ethv1"
   ```
## Notes
The RPC and Websocket ports are only locally exposed (localhost). 
In order to expose those ports outside the local environment, you can edit lines 26 and 27 of the docker-compose.yml file:
   Default, only locally exposed:
   ```
      - "127.0.0.1:${SCNODE_WS_SERVER_PORT}:${SCNODE_WS_SERVER_PORT}"
      - "127.0.0.1:${SCNODE_REST_PORT}:${SCNODE_REST_PORT}"
   ```

   Edit in this way in order to expose the ports:
   ```
      - "${SCNODE_WS_SERVER_PORT}:${SCNODE_WS_SERVER_PORT}"
      - "${SCNODE_REST_PORT}:${SCNODE_REST_PORT}"
   ```
