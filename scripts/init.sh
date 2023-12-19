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

# Setting the Node Role
env_file_exist "${ROOT_DIR}/${ENV_FILE}"
# shellcheck disable=SC1090
SCNODE_ROLE="$(grep 'SCNODE_ROLE=' "${ROOT_DIR}/${ENV_FILE}" | cut -d '=' -f2)" || { echo "SCNODE_ROLE value is wrong. Check ${ROOT_DIR}/${ENV_FILE} file"; exit 1; }

if [ -z "${SCNODE_ROLE:-}" ]; then
  read -rp "What kind of node type would you like to run('rpc' or 'forger'): " scnode_role_value
  while [[ ! "${scnode_role_value}" =~ ^(rpc|forger)$  ]]; do
    echo -e ""Error: Node type can only be 'rpc' or 'forger'. Try again...\n""
    read -rp "What kind of node type would you like to run('rpc' or 'forger'): " scnode_role_value
  done
  sed -i'' "s/SCNODE_ROLE=.*/SCNODE_ROLE=${scnode_role_value}/g" ${ROOT_DIR}/${ENV_FILE}
  if [ ${scnode_role_value} == "forger" ]; then
    sed -i'' 's/SCNODE_FORGER_ENABLED=.*/SCNODE_FORGER_ENABLED=true/g' ${ROOT_DIR}/${ENV_FILE}
    sed -i'' 's/SCNODE_FORGER_MAXCONNECTIONS=.*/SCNODE_FORGER_MAXCONNECTIONS=20/g' ${ROOT_DIR}/${ENV_FILE}
    sed -i'' 's/SCNODE_WS_CLIENT_ENABLED=.*/SCNODE_WS_CLIENT_ENABLED=true/g' ${ROOT_DIR}/${ENV_FILE}
  else
    sed -i'' 's/SCNODE_FORGER_ENABLED=.*/SCNODE_FORGER_ENABLED=false/g' ${ROOT_DIR}/${ENV_FILE}
    sed -i'' 's/SCNODE_WS_CLIENT_ENABLED=.*/SCNODE_WS_CLIENT_ENABLED=false/g' ${ROOT_DIR}/${ENV_FILE}
  fi
fi

# Checking if .env file exist and sourcing
env_file_exist "${ROOT_DIR}/${ENV_FILE}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/${ENV_FILE}" || { echo "Error: could not source ${ROOT_DIR}/${ENV_FILE} file. Fix it before proceeding any further.  Exiting..."; exit 1; }
select_compose_file

# Checking if initialize script has already run
if [ -n "${SCNODE_WALLET_SEED}" ]; then
  read -rp "Seems like $(basename "${0}") script has already run. Executing it again will lead to a loss of the current wallet and ${CONTAINER_NAME} node restart if running. Please consider taking a backup of your WALLET SEEDPHRASE before proceeding. Do you still want to proceed (y/n)? " REPLY
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\nExiting ..."
    exit 1
  fi
fi

# Setting NODENADE and WALLET_SEED dynamically

if [ -z "${SCNODE_WALLET_SEED}" ]; then
  read -rp "Do you want to import an already existing seed phrase for your wallet ? ('yes' or 'no') " wallet_seed_answer
  while [[ ! "${wallet_seed_answer}" =~ ^(yes|no)$  ]]; do
    echo -e ""Error: The only allowed answers are 'yes' or 'no'. Try again...\n""
    read -rp "Do you want to import an already existing seed phrase for your wallet ? ('yes' or 'no') " wallet_seed_answer
  done
  if [ ${wallet_seed_answer} == "yes" ]; then
    read -rp "Please type or paste now the seed phrase you want to import " imported_wallet_seed
    read -rp "Do you confirm this is the seed phrase you wanna to import : ${imported_wallet_seed} ? ('yes' or 'no')" wallet_seed_answer_2
    while [[ ! "${wallet_seed_answer_2}" =~ ^(yes|no)$  ]]; do
      echo -e ""Error: The only allowed answers are 'yes' or 'no'. Try again...\n""
      read -rp "Do you confirm this is the seed phrase you wanna to import : ${imported_wallet_seed} ? ('yes' or 'no')" wallet_seed_answer_2
    done
    if [ ${wallet_seed_answer_2} == "yes" ]; then
      SCNODE_WALLET_SEED=${imported_wallet_seed}
      sed -i "s/SCNODE_WALLET_SEED=.*/SCNODE_WALLET_SEED=${imported_wallet_seed}/g" "${ROOT_DIR}/${ENV_FILE}"
    else
     fn_die "Wallet seed phrase import aborted; please run again the init.sh script. Exiting ..." 
    fi
  else
    SCNODE_WALLET_SEED="$(pwgen 64 1)" || { echo "Error: could not set SCNODE_WALLET_SEED variable for some reason. Fix it before proceeding any further.  Exiting..."; exit 1; }
    echo "" && echo "=== PLEASE SAVE YOUR WALLET SEED PHRASE AND KEEP IT SAFE ===" && echo ""
    echo "" && echo "Your Seed phrase is : ${SCNODE_WALLET_SEED}" && echo ""
    read -rp "Do you confirm you safely stored your Wallet Seed Phrase ? ('yes') " wallet_seed_answer_3
    sed -i "s/SCNODE_WALLET_SEED=.*/SCNODE_WALLET_SEED=${SCNODE_WALLET_SEED}/g" "${ROOT_DIR}/${ENV_FILE}"
    while [[ ! "${wallet_seed_answer_3}" =~ ^(yes)$  ]]; do
      echo -e ""You should safely store your seed phrase. Please try again...\n""
      read -rp "Do you confirm you safely stored your Wallet Seed Phrase ? ('yes') " wallet_seed_answer_3
    done
  fi
fi

SCNODE_NET_NODENAME="ext-partner-$((RANDOM%100000+1))" || { echo "Error: could not set NODE_NAME variable for some reason. Fix it before proceeding any further.  Exiting..."; exit 1; }
sed -i "s/SCNODE_NET_NODENAME=.*/SCNODE_NET_NODENAME=${SCNODE_NET_NODENAME}/g" "${ROOT_DIR}/${ENV_FILE}"

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
  $COMPOSE_CMD -f ${compose_file} up -d
elif [ -n "$(docker ps -q -f status=running -f name="${CONTAINER_NAME}")" ]; then
  echo "" && echo "=== ${CONTAINER_NAME} node is already running.  Re-starting ... ===" && echo ""

  docker update --restart=no "${CONTAINER_NAME}" &>/dev/null
  $COMPOSE_CMD -f ${compose_file} exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/node/stop" -H "accept: application/json" -H 'Content-Type: application/json' &>/dev/null
  sleep 5

  $COMPOSE_CMD -f ${compose_file} up -d
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
