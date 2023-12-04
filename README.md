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
    If this is the first time you run the initialize, the script will ask you which kind of node would you like to run (a forger node or a rpc node).
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

## Running a Forger Node 
Should you want to run a forger node, please select "forger" when you run the init.sh script for the first time. Keep in mind it will take time for the Mainchain node and the sidechain node to fully sync the whole chains.

Step by step guide : 

1 - On init.sh script select "forger" when prompted. 
2 - Once the Evm node and the Mainchain node are up&running, run the generate_forger_keys script 
    ```shell
    ./scripts/generate_forger_keys.sh
    ```
    The script will generate for you all the necessary keys on the local node. The script output will be 
    ```shell
      Forger Keys (Generated Vrf public key)
      blockSignPublicKey (Generated blockSignPublicKey)
      ethereum compatible address key pair (Generated Ethereum address)
    ```

3 - At this point, in order to stake on EON via smart contract, you will create a Forging Stake using Web3js; 
    Here is an example (to be run in the Remix IDE) of creating the forging stake with a smart contract interaction:
    ```shell
(async () => {
    try {

        console.log('Running testWeb3 - Delegate or create a new Forging Stake script...')

        const smartContractAddress = "0x0000000000000000000022222222222222222222";
        const amount = 0.001; // amount of ZEN of the new stake
        const accounts = await web3.eth.getAccounts();
        console.log('Account ' + accounts[0]);

        const abi = require("browser/contracts/artifacts/abi_fs.json"); // Change this for different path

        const contract = new web3.eth.Contract(abi, smartContractAddress, {from: accounts[0]});

        // Testing method:  delegate
        const ownerAddress = accounts[0];
        // pick one of the existing forgers, or create a new forger
        const blockSignPublicKey = "0x" + YOUR_BLOCK_SIGN; // the address that will sign the block when forged; you have to populate this with the value "blockSignPublicKey" you received in the previous step
        const forgerVrfPublicKey = "0x" + YOUR_VRF_KEY; // this is the key created in the previous step (Forger Keys)
        const first32BytesForgerVrfPublicKey = forgerVrfPublicKey.substring(0, 66);
        const lastByteForgerVrfPublicKey = "0x" + forgerVrfPublicKey.substring(66, 68);

        methodName = 'delegate';
        console.log('Response for '+ methodName);

        const response = await contract.methods.delegate(blockSignPublicKey,first32BytesForgerVrfPublicKey,lastByteForgerVrfPublicKey,ownerAddress).send({value: amount *10**18}).then(console.log);

    } catch (e) {
        console.log("Error:" + e.message);
    }
  })()
        ```

⚠️ Remember to replace YOUR_BLOCK_SIGN and YOUR_VRF_KEY with the actual keys, and to specify the path of the native contract ABI. The contract ABI is not provided here, but it is available with the complete Remix workspace.
⚠️ Notice that this operation involves increasing the voting power of the forger defined by the blockSignPublicKey and forgerVrfKey, and with that the chance to produce blocks. In case of delegation of stake no rewards will be automatically forwarded to you if you are not the owner of both blockSignPublicKey and forgerVrfKey. Ensure ownership before executing the transaction. The transaction is reversible by executing a transaction signed by the ownerAddress.
Feel free to use Horizen documentation on how to use Remix : https://docs.horizen.io/horizen_eon/develop_and_deploy_smart_contracts/remix

4 - Please keep in mind all the rewards will be received on the local EVM node you're running. You can choose if you want to withdraw the rewards, send them to a different address or import on MetaMask the address in order to view the balance there directly. Please take a look at 
  a)https://github.com/HorizenOfficial/eon/blob/main/doc/api/wallet/exportSecret.md to eventually export the private key of your wallet and then import it on MetaMask
  b)https://github.com/HorizenOfficial/eon/blob/main/doc/api/transaction/sendTransaction.md to send the rewards to a different wallet on EON network
  c)https://github.com/HorizenOfficial/eon/blob/main/doc/api/transaction/withdrawCoins.md to send the rewards back on a Mainchain wallet (Horizen Network Network)
