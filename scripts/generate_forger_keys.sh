#!/bin/bash
set -eEuo pipefail

scripts_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${scripts_dir}"/utils.sh


######
# Checking all the requirements
######
echo "" && echo "=== Checking all the requirements ===" && echo ""
have_docker
have_compose_v2
have_jq

vars_to_check=(
  "CONTAINER_NAME"
  "ROOT_DIR"
)

for var in "${vars_to_check[@]}"; do
  check_env_var "${var}"
  export "${var}"
done

# Checking if .env file exist and sourcing
env_file_exist "${ROOT_DIR}/${ENV_FILE}"
source "${ROOT_DIR}/${ENV_FILE}" || { echo "Error: could not source ${ROOT_DIR}/${ENV_FILE} file. Fix it before proceeding any further.  Exiting..."; exit 1; }
SCNODE_REST_PORT="$(grep 'SCNODE_REST_PORT=' "${ROOT_DIR}/${ENV_FILE}" | cut -d '=' -f2)" || { echo "SCNODE_REST_PORT value is wrong. Check ${ROOT_DIR}/${ENV_FILE} file"; exit 1; }
export SCNODE_REST_PORT
select_compose_file

# Checking if init.sh script was executed or not
scnode_wallet_seed="$(grep 'SCNODE_WALLET_SEED=' "${ROOT_DIR}/${ENV_FILE}" | cut -d '=' -f2)" || { echo "SCNODE_WALLET_SEED value is wrong. Check ${ROOT_DIR}/${ENV_FILE} file"; exit 1; }
if [ -z "${scnode_wallet_seed}" ]; then
  fn_die "The stack was not yet initialized. Run init.sh script first. There is nothing to start.  Exiting ..."
fi

# Generate Vrf Key (forger keys)
VRF_KEY="$($COMPOSE_CMD -f ${compose_file} exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/createVrfSecret" -H "accept: application/json" -H 'Content-Type: application/json' | jq .result[].publicKey)" 

echo "Generated Vrf public key : ${VRF_KEY}"
sleep 1 

# Generate blockSignPublicKey (blockSignPublicKey)
BLOCK_SIGN_KEY="$($COMPOSE_CMD -f ${compose_file} exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/createPrivateKeySecp256k1" -H "accept: application/json" -H 'Content-Type: application/json' | jq .result[].address)"

echo "Generated blockSignPublicKey : ${BLOCK_SIGN_KEY}"
sleep 1

#Generate PrivateKeySecp256k1 (Ethereum compatible address key pair)
ETH_ADDRESS="$($COMPOSE_CMD -f ${compose_file} exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/createPrivateKey25519" -H "accept: application/json" -H 'Content-Type: application/json' | jq .result[].publicKey)"

echo "Generated Ethereum address : ${ETH_ADDRESS}"

