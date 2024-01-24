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
  export "${var?}"
done

# Checking if .env file exist and sourcing
env_file_exist "${ROOT_DIR}/${ENV_FILE}"
SCNODE_ROLE="$(grep 'SCNODE_ROLE=' "${ROOT_DIR}/${ENV_FILE}" | cut -d '=' -f2)" || { echo "SCNODE_ROLE value is wrong. Check ${ROOT_DIR}/${ENV_FILE} file"; exit 1; }
SCNODE_REST_PORT="$(grep 'SCNODE_REST_PORT=' "${ROOT_DIR}/${ENV_FILE}" | cut -d '=' -f2)" || { echo "SCNODE_REST_PORT value is wrong. Check ${ROOT_DIR}/${ENV_FILE} file"; exit 1; }
export SCNODE_REST_PORT
select_compose_file

# Cheking if the right stack is running
if [ "${SCNODE_ROLE}" != "forger" ]; then
  fn_die "Error: this script is meant to be run for FORGER role only. Your EVMAPP node is currently setup as ${SCNODE_ROLE}. Please check your ${ROOT_DIR}/${ENV_FILE} file and re-initialize as forger if needed. Exiting ..."
fi

# Checking if init.sh script was executed or not
scnode_wallet_seed="$(grep 'SCNODE_WALLET_SEED=' "${ROOT_DIR}/${ENV_FILE}" | cut -d '=' -f2)" || { echo "SCNODE_WALLET_SEED value is wrong. Check ${ROOT_DIR}/${ENV_FILE} file"; exit 1; }
if [ -z "${scnode_wallet_seed}" ]; then
  fn_die "Error: your EVMAPP node was not initialized yet and/or the wallet seed has not been generated. Please run 'init.sh' script or check your ${ROOT_DIR}/${ENV_FILE} file. Exiting ..."
fi

# Checking if the evm node is running
if [ -n "$(docker ps -q -f status=running -f name="${CONTAINER_NAME}")" ]; then
  echo "Checking if the node is reachable..."
  scnode_start_check

  # Generate Vrf Key Pair (forger keys)
  vrf_pubkey="$($COMPOSE_CMD -f "${compose_file}" exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/createVrfSecret" -H "accept: application/json" -H 'Content-Type: application/json' | jq -rc '.result[].publicKey')"
  vrf_privkey="$($COMPOSE_CMD -f "${compose_file}" exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/exportSecret" -H "accept: application/json" -H 'Content-Type: application/json' -d '{"publickey": "'"${vrf_pubkey}"'"}'| jq -rc '.result.privKey')"

  echo -e "\nGenerated VRF Key Pair."
  echo "VRF Public Key         : ${vrf_pubkey}"
  echo "VRF Private Key        : ${vrf_privkey}"
  sleep 1

  # Generate blockSign Key Pair (blockSignPublicKey)
  block_sign_pubkey="$($COMPOSE_CMD -f "${compose_file}" exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/createPrivateKey25519" -H "accept: application/json" -H 'Content-Type: application/json' | jq -rc '.result[].publicKey')"
  block_sign_privkey="$($COMPOSE_CMD -f "${compose_file}" exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/exportSecret" -H "accept: application/json" -H 'Content-Type: application/json' -d '{"publickey": "'"${block_sign_pubkey}"'"}'| jq -rc '.result.privKey')"

  echo -e "\nGenerated Block Sign Key Pair."
  echo "Block Sign Public Key  : ${block_sign_pubkey}"
  echo "Block Sign Private Key : ${block_sign_privkey}"
  sleep 1

  # Generate PrivateKeySecp256k1 (Ethereum compatible address key pair)
  eth_address="$($COMPOSE_CMD -f "${compose_file}" exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/createPrivateKeySecp256k1" -H "accept: application/json" -H 'Content-Type: application/json' | jq -rc '.result[].address')"
  eth_privkey="$($COMPOSE_CMD -f "${compose_file}" exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/exportSecret" -H "accept: application/json" -H 'Content-Type: application/json' -d '{"publickey": "'"${eth_address}"'"}'| jq -rc '.result.privKey')"

  echo -e "\nGenerated Ethereum Address Key Pair."
  echo "Ethereum Address       : 0x${eth_address}"
  echo "Ethereum Private Key   : ${eth_privkey}"
else
  fn_die "Error: ${CONTAINER_NAME} node is not running. Make sure it is up and running in order to be able to generate FORGER keys. Exiting ..."
fi
