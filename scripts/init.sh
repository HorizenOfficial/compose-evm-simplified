#!/bin/bash

set -eEuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
source "${ROOT_DIR}"/scripts/utils.sh

echo -e "\n\033[1m=== Checking all the requirements ===\033[0m"

verify_required_commands

compose_command="$(set_compose_command)"

echo -e "\n\033[1mWhat kind of node type would you like to run: \033[0m"
select role_value in rpc forger; do
  if [ -n "${role_value}" ]; then
    echo -e "\nYou have selected: \033[1m${role_value}\033[0m"
    break
  else
    echo -e "\n\033[1mInvalid selection. Please type 1, or 2.\033[0m\n"
  fi
done

echo -e "\n\033[1mWhat network would you like to setup 'eon' (mainnet) or 'gobi' (testnet): \033[0m"
select network_value in eon gobi; do
  if [ -n "${network_value}" ]; then
    echo -e "\nYou have selected: \033[1m${network_value}\033[0m"
    break
  else
    echo -e "\n\033[1mInvalid selection. Please type 1, or 2.\033[0m\n"
  fi
done

echo -e "\n\033[1m=== Preparing deployment directory ./${role_value}/${network_value} ===\033[0m"
DEPLOYMENT_DIR="${ROOT_DIR}/deployments/${role_value}/${network_value}"
mkdir -p "${DEPLOYMENT_DIR}" || fn_die "Error: could not create deployment directory. Fix it before proceeding any further.  Exiting..."

echo -e "\n\033[1m=== Creating .env file ===\033[0m"
ENV_FILE_TEMPLATE="${ROOT_DIR}/env/.env.${role_value}.${network_value}.template"
ENV_FILE="${DEPLOYMENT_DIR}/.env"

if ! [ -f "${ENV_FILE}" ]; then
  cp "${ENV_FILE_TEMPLATE}" "${ENV_FILE}"
  # shellcheck source=../.env.forger.eon
  source "${ENV_FILE}" || fn_die "Error: could not source ${ENV_FILE} file. Fix it before proceeding any further.  Exiting..."

  # Setting SCNODE_NET_NODENAME and SCNODE_WALLET_SEED dynamically
  if [ -z "${SCNODE_WALLET_SEED}" ]; then
    echo -e "\n\033[1m=== Setting up the wallet seed phrase ===\033[0m\n"
    read -rp "Do you want to import an already existing seed phrase for your wallet ? ('yes' or 'no') " wallet_seed_answer
    while [[ ! "${wallet_seed_answer}" =~ ^(yes|no)$ ]]; do
      echo -e "\nError: The only allowed answers are 'yes' or 'no'. Try again...\n"
      read -rp "Do you want to import an already existing seed phrase for your wallet ? ('yes' or 'no') " wallet_seed_answer
    done
    if [ "${wallet_seed_answer}" = "yes" ]; then
      read -rp "Please type or paste now the seed phrase you want to import: " imported_wallet_seed
      read -rp "Do you confirm this is the seed phrase you want to import : ${imported_wallet_seed} ? ('yes' or 'no') " wallet_seed_answer_2
      while [[ ! "${wallet_seed_answer_2}" =~ ^(yes|no)$ ]]; do
        echo -e "\nError: The only allowed answers are 'yes' or 'no'. Try again...\n"
        read -rp "Do you confirm this is the seed phrase you want to import : ${imported_wallet_seed} ? ('yes' or 'no') " wallet_seed_answer_2
      done
      if [ "${wallet_seed_answer_2}" = "yes" ]; then
        SCNODE_WALLET_SEED="${imported_wallet_seed}"
        sed -i "s/SCNODE_WALLET_SEED=.*/SCNODE_WALLET_SEED=${imported_wallet_seed}/g" "${ENV_FILE}"
      else
        fn_die "Wallet seed phrase import aborted; please run again the init.sh script. Exiting ..."
      fi
    else
      SCNODE_WALLET_SEED="$(pwgen 64 1)" || fn_die "Error: could not set SCNODE_WALLET_SEED variable for some reason. Fix it before proceeding any further.  Exiting..."
      echo -e "\n\033[1m=== PLEASE SAVE YOUR WALLET SEED PHRASE AND KEEP IT SAFE ===\033[0m"
      echo -e "\nYour Seed phrase is : \033[1m${SCNODE_WALLET_SEED}\033[0m\n"
      read -rp "Do you confirm you safely stored your Wallet Seed Phrase ? ('yes') " wallet_seed_answer_3
      while [[ ! "${wallet_seed_answer_3}" =~ ^(yes)$ ]]; do
        echo -e "\nYou should safely store your seed phrase. Please try again...\n"
        read -rp "Do you confirm you safely stored your Wallet Seed Phrase ? ('yes') " wallet_seed_answer_3
      done
      if [ "${wallet_seed_answer_3}" = "yes" ]; then
        sed -i "s/SCNODE_WALLET_SEED=.*/SCNODE_WALLET_SEED=${SCNODE_WALLET_SEED}/g" "${ENV_FILE}"
      fi
    fi
  fi

  SCNODE_NET_NODENAME="ext-partner-$((RANDOM % 100000 + 1))" || fn_die "Error: could not set NODE_NAME variable for some reason. Fix it before proceeding any further.  Exiting..."

  sed -i "s/SCNODE_NET_NODENAME=.*/SCNODE_NET_NODENAME=${SCNODE_NET_NODENAME}/g" "${ENV_FILE}"

  if [ "${role_value}" = "forger" ]; then
    echo -e "\nYou are setting up a forger node with a zend node. Zend node may require a few hours to sync.\n"
    read -rp "Do you want to download and use a seed file to speed up the process? ('yes' or 'no'): " use_seed_answer
    while [[ ! "${use_seed_answer}" =~ ^(yes|no)$ ]]; do
      echo -e "\nError: The only allowed answers are 'yes' or 'no'. Try again...\n"
      read -rp "Do you want to download and use a seed file to speed up the process? ('yes' or 'no'): " use_seed_answer
    done
    if [ "${use_seed_answer}" = "yes" ]; then
      sed -i "s/ZEN_USE_SEED_FILE=.*/ZEN_USE_SEED_FILE=true/g" "${ENV_FILE}"
    fi
  fi
fi

# shellcheck source=../deployments/eon/forger/.env
source "${ENV_FILE}" || fn_die "Error: could not source ${ENV_FILE} file. Fix it before proceeding any further.  Exiting..."

check_required_variables

echo -e "\n\033[1m=== Creating symlink to compose file ===\033[0m"
COMPOSE_FILE="${ROOT_DIR}/compose_files/docker-compose-${role_value}.yml"
SYMLINK_COMPOSE_FILE="${DEPLOYMENT_DIR}/docker-compose.yml"
if ! [ -L "${SYMLINK_COMPOSE_FILE}" ]; then
  ln -sf "${COMPOSE_FILE}" "${SYMLINK_COMPOSE_FILE}"
fi

if [ "${role_value}" = "forger" ]; then

  echo -e "\n\033[1m=== Creating symlink to seed file ===\033[0m"
  SEED_FILE="${ROOT_DIR}/scripts/forger/seed.sh"
  SYMLINK_SEED_FILE="${DEPLOYMENT_DIR}/scripts/seed.sh"
  if ! [ -L "${SYMLINK_SEED_FILE}" ]; then
    mkdir -p "${DEPLOYMENT_DIR}/scripts"
    ln -sf "${SEED_FILE}" "${SYMLINK_SEED_FILE}"
  fi

  EXPLORER_URL="https://explorer.horizen.io"
  if [ "${network_value}" = "gobi" ]; then
    EXPLORER_URL="https://explorer-testnet.horizen.io"
  fi

  echo -e "\n\033[1m=== Project has been setup correctly for ${role_value} and ${network_value} ===\033[0m"

  echo -e "\n\033[1m=== RUNNING FORGER NODE ===\033[0m\n"

  echo -e "1. Run first the zend node:"

  echo -e "\n\033[1mcd ${DEPLOYMENT_DIR} && ${compose_command} up -d zend\033[0m\n"

  echo -e "2. Verify height of the explorer: ${EXPLORER_URL} matches your node height:"

  echo -e "\n\033[1mdocker exec ${ZEND_CONTAINER_NAME} gosu user curl -s --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"getblockcount\", \"params\": [] }' -H 'content-type: text/plain;' -u [ZEN_RPC_USER]:[ZEN_RPC_PASSWORD] http://127.0.0.1:${ZEN_RPC_PORT}/\033[0m\n"

  echo -e "3. Once the zend node is fully synced, start the evmapp node:"

  echo -e "\n\033[1mcd ${DEPLOYMENT_DIR} && ${compose_command} up -d\033[0m"

  echo -e "\n\033[1m===========================\033[0m\n"
else

  echo -e "\n\033[1m=== Project has been setup correctly for ${role_value} and ${network_value} ===\033[0m"

  echo -e "\n\033[1m=== RUNNING RPC NODE ===\033[0m\n"

  echo -e "1.Start the evmapp node:"

  echo -e "\n\033[1mcd ${DEPLOYMENT_DIR} && ${compose_command} up -d\033[0m"

  echo -e "\n\033[1m========================\033[0m\n"
fi

exit 0
