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
4. Run the following command to stop the stack:
    ```shell
    ./scripts/stop.sh
    ```
5. Run the following command to stop the stack and delete the containers:
    ```shell
    ./scripts/shutdown.sh
    ```
6. Run the following command to start the stack after it was stopped:
    ```shell
    ./scripts/startup.sh
    ```
7. Run the following command to destroy the stack, **this action will delete your wallet and all the data**:
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
If you intend to run a **forger** node, please select 'forger' when executing the 'init.sh' script for the first time. Keep in mind that both the Mainchain node and the Sidechain node will require some time to fully synchronize the entire chains.

### Step-by-step guide ### 

1. During init.sh script run choose 'forger' when prompted. 
2. Once the EVM node and the Mainchain node are up and running, run the 'generate_forger_keys.sh' script. 
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
      Ethereum Address       : ...
      Ethereum Private Key   : ...
    ```

3. At this stage, to participate in staking on EON, utilize a smart contract to create a Forging Stake using Web3.js. 
Below is an example (to be executed in the Remix IDE) demonstrating how to create a forging stake through smart contract interaction:
    ```shell
        (async () => {
            try {
                console.log('Running testWeb3 - Delegate or create a new Forging Stake script...')

                const smartContractAddress = "0x0000000000000000000022222222222222222222";
                const amount = 0.001; // amount of ZEN of the new stake
                const accounts = await web3.eth.getAccounts();
                console.log('Account ' + accounts[0]);

                const abi = require("abi/forger_stake_delegation.json"); // Download the file from the repo and change this to the correct path of the file

                const contract = new web3.eth.Contract(abi, smartContractAddress, {from: accounts[0]});

                // Testing method:  delegate
                const ownerAddress = accounts[0];
                // pick one of the existing forgers, or create a new forger
                const blockSignPublicKey = "0x" + YOUR_BLOCK_SIGN_PUBKEY; // the public key that will sign the block when forged; you have to populate this with the value of "Block Sign Public Key" you received in the previous step
                const forgerVrfPublicKey = "0x" + YOUR_VRF_PUBKEY; // this is the "VRF Public Key" created in the previous step
                const first32BytesForgerVrfPublicKey = forgerVrfPublicKey.substring(0, 66);
                const lastByteForgerVrfPublicKey = "0x" + forgerVrfPublicKey.substring(66, 68);

                methodName = 'delegate';
                console.log('Response for '+ methodName);

                const response = await contract.methods.delegate(blockSignPublicKey,first32BytesForgerVrfPublicKey,lastByteForgerVrfPublicKey,ownerAddress).send({value: amount *10**18}).then(console.log);

            } catch (e) {
                console.log("Error:" + e.message);
            }
        })();
    ```

### Script Usage ###
1. Remember to replace **YOUR_BLOCK_SIGN_PUBKEY** and **YOUR_VRF_PUBKEY** with the actual keys you have generated by running 'generate_forger_keys.sh' script.
2. Specify the path to the ABI contract file path, you can download it here [abi/forger_stake_delegation.json](https://raw.githubusercontent.com/HorizenOfficial/compose-evm-simplified/main/abi/forger_stake_delegation.json).
3. Notice that this operation involves increasing the voting power of the forger defined by the **blockSignPublicKey** and **forgerVrfKey**, and with that the chance to produce blocks.
4. In case of stake delegation, rewards will not be automatically forwarded unless you are the owner of both **blockSignPublicKey** and **forgerVrfKey**. Ensure ownership before proceeding with the transaction. The transaction can be reversed by executing a transaction signed by the ownerAddress. Feel free to use Horizen documentation on how to use Remix: https://docs.horizen.io/horizen_eon/develop_and_deploy_smart_contracts/remix
5. Keep in mind that you will need both nodes (Mainchain and Sidechain) to be fully synced in order to be able to successfully forge a block.
6. Please keep in mind all the rewards will be received on the local EVM node you're running. You can choose if you want to withdraw the rewards, send them to a different address or import on MetaMask address in order to view the balance there directly. Please consider the following documentation:
   1. Export the private key of your wallet and then import it in MetaMask: https://github.com/HorizenOfficial/eon/blob/main/doc/api/wallet/exportSecret.md
   2. Send the rewards to a different wallet on EON network: https://github.com/HorizenOfficial/eon/blob/main/doc/api/transaction/sendTransaction.md
   3. Send the rewards back to a Mainchain wallet (Horizen Network): https://github.com/HorizenOfficial/eon/blob/main/doc/api/transaction/withdrawCoins.md
