# Rpc Node

## Setup

--- 

Run the init.sh script to initialize the deployment for the first time. Select **rpc** node and the **network** to run (eon or gobi).

```shell
./scripts/init.sh
```

The script will generate the required deployment files under the [deployments](../deployments) directory and provide instructions on how to run the compose stack.

## Running the stack

--- 

```shell
cd deployments/rpc/[eon|gobi] && docker compose up -d
```

## Other useful docker commands

--- 

- Run the following command to stop the stack:
    ```shell
    cd deployments/rpc/[eon|gobi] && docker compose stop
    ```
- Run the following command to start the stack again:
    ```shell
    cd deployments/rpc/[eon|gobi] && docker compose up -d
    ```
- Run the following command to stop the stack and delete the containers:
    ```shell
    cd deployments/rpc/[eon|gobi] && docker compose down
    ```
- Run the following commands to destroy the stack, **this action will delete your wallet and all the data**:
    ```shell
    cd deployments/rpc/[eon|gobi] && docker compose down
    docker volume ls # List all the volumes
    docker volume rm [volume_name] # Remove the volumes related to your stack, these volumes are named after the stack name: [COMPOSE_PROJECT_NAME]_[volume-name]
    ```

## Rpc Node Usage

---

- The evmapp node RPC interfaces will be available over HTTP at http://localhost:9545/. For example:
   ```shell
   curl -sX POST -H 'accept: application/json' -H 'Content-Type: application/json' "http://127.0.0.1:9545/block/best"
   ```

- The Ethereum RPC interface is available at `/ethv1` location http://localhost:9545/ethv1. For example:
   ```shell
   curl -sX POST -H 'accept: application/json' -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}' "http://127.0.0.1:9545/ethv1"
   ```

- The RPC and WebSocket ports are only exposed locally (accessible only via localhost). In order to expose those ports outside the local environment, you can edit the following lines in the docker-compose.yml file:
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
