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
have_pwgen

vars_to_check=(
  "CONTAINER_NAME"
  "ROOT_DIR"
  "ENV_FILE"
)

for var in "${vars_to_check[@]}"; do
  check_env_var "${var}"
  export "${var}"
done

# Checking if .env file exist and sourcing
env_file_exist "${ROOT_DIR}/${ENV_FILE}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/${ENV_FILE}" || { echo "Error: could not source ${ROOT_DIR}/${ENV_FILE} file. Fix it before proceeding any further.  Exiting..."; exit 1; }

# Checking if initialize script has already run
if [ -n "${SCNODE_WALLET_SEED}" ]; then
  read -rp "Seems like $(basename "${0}") script has already run. Executing it again will lead to a loss of the current wallet and ${CONTAINER_NAME} node restart if running. Do you still want to proceed (y/n)? " REPLY
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\nExiting ..."
    exit 1
  fi
fi

# Setting NODENADE and WALLET_SEED dynamically
SCNODE_NET_NODENAME="ext-partner-$((RANDOM%100000+1))" || { echo "Error: could not set NODE_NAME variable for some reason. Fix it before proceeding any further.  Exiting..."; exit 1; }
sed -i "s/SCNODE_NET_NODENAME=.*/SCNODE_NET_NODENAME=${SCNODE_NET_NODENAME}/g" "${ROOT_DIR}/${ENV_FILE}"

SCNODE_WALLET_SEED="$(pwgen 64 1)" || { echo "Error: could not set SCNODE_WALLET_SEED variable for some reason. Fix it before proceeding any further.  Exiting..."; exit 1; }
sed -i "s/SCNODE_WALLET_SEED=.*/SCNODE_WALLET_SEED=${SCNODE_WALLET_SEED}/g" "${ROOT_DIR}/${ENV_FILE}"

# Checking all the variables
to_check=(
  "SCNODE_CERT_SIGNERS_MAXPKS"
  "SCNODE_CERT_SIGNERS_THRESHOLD"
  "SCNODE_CERT_SIGNERS_PUBKEYS"
  "SCNODE_CERT_MASTERS_PUBKEYS"
  "SCNODE_ALLOWED_FORGERS"
  "SCNODE_FORGER_RESTRICT"
  "SCNODE_GENESIS_BLOCKHEX"
  "SCNODE_GENESIS_SCID"
  "SCNODE_GENESIS_POWDATA"
  "SCNODE_GENESIS_MCBLOCKHEIGHT"
  "SCNODE_GENESIS_COMMTREEHASH"
  "SCNODE_GENESIS_WITHDRAWALEPOCHLENGTH"
  "SCNODE_GENESIS_MCNETWORK"
  "SCNODE_GENESIS_ISNONCEASING"
  "SCNODE_NET_KNOWNPEERS"
  "SCNODE_NET_MAGICBYTES"
  "SCNODE_NET_NODENAME"
  "SCNODE_NET_P2P_PORT"
  "SCNODE_REST_PORT"
  "SCNODE_USER_ID"
  "SCNODE_GRP_ID"
  "SCNODE_WS_SERVER_PORT"
  "SCNODE_WS_SERVER_ENABLED"
  "SCNODE_WALLET_SEED"
  "SCNODE_WALLET_MAXTX_FEE"
  "SC_COMMITTISH_EVMAPP"
)

# Making sure all the variables are set
for var in "${to_check[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "Error: Environment variable ${var} is required."

    # Unset all the sourced variables
    for i in "${to_check[@]}"; do
      unset "${i}"
    done
    sleep 5

    echo "Thanks for your interest in EON, your configuration is incomplete. Application will not be able to start. Please contact Horizen to fix this issue. Exiting ..."
    exit 1
  fi
done


######
# Starting evmapp
######
cd "${ROOT_DIR}"

if [ -z "$(docker ps -q -f status=running -f name="${CONTAINER_NAME}")" ]; then
  echo "" && echo "=== Starting ${CONTAINER_NAME} node ===" && echo ""
  $COMPOSE_CMD up -d
elif [ -n "$(docker ps -q -f status=running -f name="${CONTAINER_NAME}")" ]; then
  echo "" && echo "=== ${CONTAINER_NAME} node is already running.  Re-starting ... ===" && echo ""

  docker update --restart=no "${CONTAINER_NAME}" &>/dev/null
  $COMPOSE_CMD exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/node/stop" -H "accept: application/json" -H 'Content-Type: application/json' &>/dev/null
  sleep 5

  $COMPOSE_CMD up -d
  docker update --restart=always "${CONTAINER_NAME}" &>/dev/null
fi

# Making sure scnode is up and running
scnode_start_check

# Unset all the variable after app start check is completed
for var in "${to_check[@]}"; do
  unset "${var}"
done


######
# The END
######
echo "" && echo "=== ${CONTAINER_NAME} node was successfully checked and (re)started ===" && echo ""
exit 0
