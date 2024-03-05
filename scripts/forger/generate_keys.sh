#!/bin/bash

set -eEuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ROOT_DIR="$(readlink -f "${script_dir}/../..")"
source "${ROOT_DIR}"/scripts/utils.sh

echo -e "\n\033[1m=== Checking all the requirements ===\033[0m"

verify_required_commands

echo -e "\n\033[1mWhat network would you like to generate the keys on 'eon' (mainnet) or 'gobi' (testnet): \033[0m"
select network_value in eon gobi; do
  if [ -n "${network_value}" ]; then
    echo -e "\nYou have selected: \033[1m${network_value}\033[0m"
    break
  else
    echo -e "\n\033[1mInvalid selection. Please type 1, or 2.\033[0m\n"
  fi
done

DEPLOYMENT_DIR="${ROOT_DIR}/deployments/forger/${network_value}"
ENV_FILE="${DEPLOYMENT_DIR}/.env"

# shellcheck source=../deployments/forger/eon/.env
source "${ENV_FILE}" || fn_die "Error: could not source ${ENV_FILE} file. Fix it before proceeding any further.  Exiting..."

# Checking if the right stack is running
if [ "${SCNODE_ROLE}" != "forger" ]; then
  fn_die "Error: this script is meant to be run for FORGER role only. Your EVMAPP node is currently setup as ${SCNODE_ROLE}. Please check your ${ENV_FILE} file and re-initialize as forger if needed. Exiting ..."
fi

# Checking if setup.sh script was executed or not
if [ -z "${SCNODE_WALLET_SEED}" ]; then
  fn_die "Error: your EVMAPP node was not initialized yet and/or the wallet seed has not been generated. Please run 'setup.sh' script or check your ${ENV_FILE} file. Exiting ..."
fi

# Checking if the evm node is running
if [ -n "$(docker ps -q -f status=running -f name="${EVMAPP_CONTAINER_NAME}")" ]; then
  echo "Checking if the node is reachable..."
  scnode_start_check

  # Generate Vrf Key Pair (forger keys)
  vrf_pubkey="$(docker exec "${EVMAPP_CONTAINER_NAME}" gosu user curl -sXPOST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/createVrfSecret" -H "accept: application/json" -H 'Content-Type: application/json' | jq -rc '.result[].publicKey')"
  vrf_privkey="$(docker exec "${EVMAPP_CONTAINER_NAME}" gosu user curl -sXPOST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/exportSecret" -H "accept: application/json" -H 'Content-Type: application/json' -d '{"publickey": "'"${vrf_pubkey}"'"}'| jq -rc '.result.privKey')"

  echo -e "\nGenerated VRF Key Pair."
  echo "VRF Public Key         : ${vrf_pubkey}"
  echo "VRF Private Key        : ${vrf_privkey}"
  sleep 1

  # Generate blockSign Key Pair (blockSignPublicKey)
  block_sign_pubkey="$(docker exec "${EVMAPP_CONTAINER_NAME}" gosu user curl -sXPOST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/createPrivateKey25519" -H "accept: application/json" -H 'Content-Type: application/json' | jq -rc '.result[].publicKey')"
  block_sign_privkey="$(docker exec "${EVMAPP_CONTAINER_NAME}" gosu user curl -sXPOST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/exportSecret" -H "accept: application/json" -H 'Content-Type: application/json' -d '{"publickey": "'"${block_sign_pubkey}"'"}'| jq -rc '.result.privKey')"

  echo -e "\nGenerated Block Sign Key Pair."
  echo "Block Sign Public Key  : ${block_sign_pubkey}"
  echo "Block Sign Private Key : ${block_sign_privkey}"
  sleep 1

  # Generate PrivateKeySecp256k1 (Ethereum compatible address key pair)
  eth_address="$(docker exec "${EVMAPP_CONTAINER_NAME}" gosu user curl -sXPOST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/createPrivateKeySecp256k1" -H "accept: application/json" -H 'Content-Type: application/json' | jq -rc '.result[].address')"
  eth_privkey="$(docker exec "${EVMAPP_CONTAINER_NAME}" gosu user curl -sXPOST "http://127.0.0.1:${SCNODE_REST_PORT}/wallet/exportSecret" -H "accept: application/json" -H 'Content-Type: application/json' -d '{"publickey": "'"${eth_address}"'"}'| jq -rc '.result.privKey')"

  # Remove first two digits of the private key and concat 0x to the beginning
  eth_privkey_metamask="0x${eth_privkey:2}"

  echo -e "\nGenerated Ethereum Address Key Pair."
  echo "Ethereum Address                    : 0x${eth_address}"
  echo "Ethereum Private Key                : ${eth_privkey}"
  echo "Ethereum Private Key for MetaMask   : ${eth_privkey_metamask}"

  echo -e "\n\033[1m=== STORE ALL THESE VALUES IN A SAFE PLACE ===\033[0m"
else
  fn_die "Error: ${EVMAPP_CONTAINER_NAME} node is not running. Make sure it is up and running in order to be able to generate FORGER keys. Exiting ..."
fi
