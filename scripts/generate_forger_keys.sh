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
SCNODE_ROLE="$(grep 'SCNODE_ROLE=' "${ROOT_DIR}/${ENV_FILE}" | cut -d '=' -f2)" || { echo "SCNODE_ROLE value is wrong. Check ${ROOT_DIR}/${ENV_FILE} file"; exit 1; }
SCNODE_REST_PORT="$(grep 'SCNODE_REST_PORT=' "${ROOT_DIR}/${ENV_FILE}" | cut -d '=' -f2)" || { echo "SCNODE_REST_PORT value is wrong. Check ${ROOT_DIR}/${ENV_FILE} file"; exit 1; }
export SCNODE_REST_PORT
select_compose_file

# Checking if init.sh script was executed or not
scnode_wallet_seed="$(grep 'SCNODE_WALLET_SEED=' "${ROOT_DIR}/${ENV_FILE}" | cut -d '=' -f2)" || { echo "SCNODE_WALLET_SEED value is wrong. Check ${ROOT_DIR}/${ENV_FILE} file"; exit 1; }
if [ -z "${scnode_wallet_seed}" ]; then
  fn_die "The stack was not yet initialized. The wallet seed has not been populated correctly. Please run init.sh script or check your  "${ROOT_DIR}/${ENV_FILE}" file. Exiting ..."
fi

# Checking if the evm node is running 
if [ -n "$(docker ps -q -f status=running -f name="${CONTAINER_NAME}")" ]; then
  echo "Checking if the node is reachable..."
  scnode_start_check

  # Generate Vrf Key (forger keys)
  vrf_key="$($COMPOSE_CMD -f ${compose_file} exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/createVrfSecret" -H "accept: application/json" -H 'Content-Type: application/json' | jq .result[].publicKey)" 

  echo "Generated Vrf public key : ${vrf_key}"
  sleep 1 

  # Generate blockSignPublicKey (blockSignPublicKey)
  block_sign_key="$($COMPOSE_CMD -f ${compose_file} exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/createPrivateKeySecp256k1" -H "accept: application/json" -H 'Content-Type: application/json' | jq .result[].address)"

  echo "Generated blockSignPublicKey : ${block_sign_key}"
  sleep 1

  #Generate PrivateKeySecp256k1 (Ethereum compatible address key pair)
  eth_address="$($COMPOSE_CMD -f ${compose_file} exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/createPrivateKey25519" -H "accept: application/json" -H 'Content-Type: application/json' | jq .result[].publicKey)"

  echo "Generated Ethereum address : ${eth_address}"
else
  fn_die "=== ${CONTAINER_NAME} node is not running. You need to start ${CONTAINER_NAME} node to be able to generate the keys ==="
fi
