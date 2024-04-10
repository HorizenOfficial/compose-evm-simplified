#!/bin/bash
set -eEuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
source "${ROOT_DIR}"/scripts/utils.sh

echo -e "\n\033[1m=== Checking all the requirements ===\033[0m"

verify_required_commands

# Making sure the script is not being run as root
LOCAL_USER_ID="$(id -u)"
LOCAL_GROUP_ID="$(id -g)"
if [ "${LOCAL_USER_ID}" == 0 ] || [ "${LOCAL_GROUP_ID}" == 0 ]; then
  fn_die "Error: This script should not be run as root. Exiting..."
fi

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
        # Removing env_file since exit script will leave it in incomplete state
        rm -f "${ENV_FILE}"
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
  SCNODE_NET_NODENAME="ext-${role_value}-$((RANDOM % 100000 + 1))" || fn_die "Error: could not set NODE_NAME variable for some reason. Fix it before proceeding any further.  Exiting..."
  sed -i "s/SCNODE_NET_NODENAME=.*/SCNODE_NET_NODENAME=${SCNODE_NET_NODENAME}/g" "${ENV_FILE}"

  # Setting explicit wallet address for forger rewards to be sent to vs default local forger
  if [ "${role_value}" = "forger" ]; then
    echo -e "\n\033[1m=== Setting up FORGER rewards address ===\033[0m\n"
    read -rp "Do you want to provide the wallet address for your FORGER rewards to be sent to (FORGER local wallet address is used by default)? ('yes' or 'no') " reward_address_set
    while [[ ! "${reward_address_set}" =~ ^(yes|no)$ ]]; do
      echo -e "\nWarning: The only allowed answers are 'yes' or 'no'. Please try again...\n"
      read -rp "Do you want to provide the wallet address for your FORGER rewards to be sent to (FORGER local wallet address is used by default)? ('yes' or 'no') " reward_address_set
    done
    if [ "${reward_address_set}" = "yes" ]; then
      read -rp "Please type or copy/paste here the wallet address for your FORGER rewards to be sent to: " forger_reward_address
      echo -e "\nYou have provided the following wallet address: \033[1m${forger_reward_address}\033[0m\n"
      read -rp "Do you confirm this is the wallet address you want to use for your FORGER rewards to be sent to: ${forger_reward_address}? ('yes' or 'no') " reward_address_set_2
      while [[ ! "${reward_address_set_2}" =~ ^(yes|no)$ ]]; do
        echo -e "\nWarning: The only allowed answers are 'yes' or 'no'. Please try again...\n"
        read -rp "Do you confirm this is the wallet address you want to use for your FORGER rewards to be sent to: ${forger_reward_address}? ('yes' or 'no') " reward_address_set_2
      done
      if [ "${reward_address_set_2}" = "yes" ]; then
        forger_reward_address="$(strip_0x "${forger_reward_address}")"
        if [ "${forger_reward_address}" != "invalid" ]; then
          sed -i "s/SCNODE_FORGER_REWARD_ADDRESS=.*/SCNODE_FORGER_REWARD_ADDRESS=${forger_reward_address}/g" "${ENV_FILE}"
        else
          # Removing env_file since exit script will leave it in incomplete state
          rm -f "${ENV_FILE}"
          fn_die "Error: Provided wallet address is in the WRONG format.\n\n=== An Ethereum address is a 42-character hexadecimal address derived from the last 20 bytes of the public key controlling the account with '0x' appended in front ===\n\nPlease re-run the init.sh script again. Exiting ..."
        fi
      else
        # Removing env_file since exit script will leave it in incomplete state
        rm -f "${ENV_FILE}"
        fn_die "Error: Setting wallet address to send FORGER rewards to has failed. Please re-run the init.sh script again. Exiting ..."
      fi
    fi
  fi

  # Setting local user and group in docker containers
  echo -e "\n\033[1m=== Setting up the docker containers local user and group ids ===\033[0m\n"
  echo -e "The uid:gid with which to run the processes inside of the container will default to ${LOCAL_USER_ID}:${LOCAL_GROUP_ID}"
  read -rp "Do you want to change the user (please answer 'no' if you don't know what you are doing) ? ('yes' or 'no') " user_group_answer
  while [[ ! "${user_group_answer}" =~ ^(yes|no)$ ]]; do
    echo -e "\nError: The only allowed answers are 'yes' or 'no'. Try again...\n"
    read -rp "Do you want to change the user (please answer 'no' if you don't know what you are doing) ? ('yes' or 'no') " user_group_answer
  done
  if [ "${user_group_answer}" = "yes" ]; then
    read -rp "Please type the user id you want to use in your docker containers (0 is an invalid value): " user_id
    while [[ ! "${user_id}" =~ ^[1-9][0-9]*$ ]]; do
      echo -e "\nError: The user id must be a positive integer and not 0. Try again...\n"
      read -rp "Please type the user id you want to use in your docker containers (0 is an invalid value): " user_id
    done
    read -rp "Please type the group id you want to use in your docker containers: " group_id
    while [[ ! "${group_id}" =~ ^[1-9][0-9]*$ ]]; do
      echo -e "\nError: The user id must be a positive integer and not 0. Try again...\n"
      read -rp "Please type the group id you want to use in your docker containers (0 is an invalid value): " group_id
    done
    LOCAL_USER_ID="${user_id}"
    LOCAL_GROUP_ID="${group_id}"
  fi
  sed -i "s/SCNODE_USER_ID=.*/SCNODE_USER_ID=${LOCAL_USER_ID}/g" "${ENV_FILE}"
  sed -i "s/SCNODE_GRP_ID=.*/SCNODE_GRP_ID=${LOCAL_GROUP_ID}/g" "${ENV_FILE}"
  if [ "${role_value}" = "forger" ]; then
    sed -i "s/ZEN_LOCAL_USER_ID=.*/ZEN_LOCAL_USER_ID=${LOCAL_USER_ID}/g" "${ENV_FILE}"
    sed -i "s/ZEN_LOCAL_GRP_ID=.*/ZEN_LOCAL_GRP_ID=${LOCAL_GROUP_ID}/g" "${ENV_FILE}"
  fi

  # Setting volumes datadir
  echo -e "\n\033[1m=== Setting up the docker volumes datadir ===\033[0m\n"
  echo -e "By default internal docker volumes will be used."
  read -rp "Do you want to change the datadir (please answer 'no' if you don't know what you are doing) ? ('yes' or 'no') " datadir_answer
  while [[ ! "${datadir_answer}" =~ ^(yes|no)$ ]]; do
    echo -e "\nError: The only allowed answers are 'yes' or 'no'. Try again...\n"
    read -rp "Do you want to change the datadir (please answer 'no' if you don't know what you are doing) ? ('yes' or 'no') " datadir_answer
  done
  if [ "${datadir_answer}" = "yes" ]; then
    default_datadir_path="./data/"
    read -rp "Please type the path to the datadir you want to use in your docker containers or press enter to use default ('${default_datadir_path}'): " datadir_path
    if [ -z "${datadir_path}" ]; then
      datadir_path="${default_datadir_path}"
    fi
    sed -i "s#COMPOSE_PROJECT_DATA_DIR=.*#COMPOSE_PROJECT_DATA_DIR=${datadir_path}#g" "${ENV_FILE}"
  fi
fi

# shellcheck source=../deployments/eon/forger/.env
source "${ENV_FILE}" || fn_die "Error: could not source ${ENV_FILE} file. Fix it before proceeding any further.  Exiting..."

check_required_variables

echo -e "\n\033[1m=== Creating symlink to compose file ===\033[0m"
COMPOSE_FILE="${ROOT_DIR}/compose_files/docker-compose-${role_value}.yml"
SYMLINK_COMPOSE_FILE="${DEPLOYMENT_DIR}/docker-compose.yml"
ln -sf "${COMPOSE_FILE}" "${SYMLINK_COMPOSE_FILE}"

if [ "${role_value}" = "forger" ]; then
  DOWNLOAD_SEED_FILE="${ROOT_DIR}/scripts/forger/seed/download_seed.sh"
  SYMLINK_SEED_DOWNLOAD_FILE="${DEPLOYMENT_DIR}/scripts/download_seed.sh"
  SEED_FILE="${ROOT_DIR}/scripts/forger/seed/seed.sh"
  SYMLINK_SEED_FILE="${DEPLOYMENT_DIR}/scripts/seed.sh"
  mkdir -p "${DEPLOYMENT_DIR}/scripts"
  ln -sf "${DOWNLOAD_SEED_FILE}" "${SYMLINK_SEED_DOWNLOAD_FILE}"
  ln -sf "${SEED_FILE}" "${SYMLINK_SEED_FILE}"

  mkdir -p "${DEPLOYMENT_DIR}/seed"

  EXPLORER_URL="https://explorer.horizen.io"
  EVMAPP_EXPLORER_URL="https://eon-explorer.horizenlabs.io"
  if [ "${network_value}" = "gobi" ]; then
    EXPLORER_URL="https://explorer-testnet.horizen.io"
    EVMAPP_EXPLORER_URL="https://gobi-explorer.horizenlabs.io"
  fi

  echo -e "\n\033[1m=== Project has been initialized correctly for ${role_value} and ${network_value} ===\033[0m"

  echo -e "\n\033[1m=== RUNNING FORGER NODE ===\033[0m\n"

  echo -e "1. First, run the zend node:"

  echo -e "\n\033[1mdocker compose -f ${DEPLOYMENT_DIR}/docker-compose.yml up -d zend\033[0m\n"

  echo -e "2. Verify your node's block height matches against the public explorer: ${EXPLORER_URL}:"

  echo -e "\n\033[1mdocker compose -f ${DEPLOYMENT_DIR}/docker-compose.yml exec zend gosu user zen-cli getblockcount\033[0m\n"

  echo -e "3. Once the zend node is fully synced, start the evmapp node:"

  echo -e "\n\033[1mdocker compose -f ${DEPLOYMENT_DIR}/docker-compose.yml up -d\033[0m"

  echo -e "4. Verify your evmapp node's block height matches against the public explorer: ${EVMAPP_EXPLORER_URL}:"

  echo -e "\n\033[1mdocker compose -f ${DEPLOYMENT_DIR}/docker-compose.yml exec evmapp gosu user bash -c 'curl -sXPOST \"http://127.0.0.1:${SCNODE_REST_PORT}/block/best\" -H \"accept: application/json\" | jq '.result.height''\033[0m\n"

  echo -e "\n\033[1m===========================\033[0m\n"
else
  echo -e "\n\033[1m=== Project has been initialized correctly for ${role_value} and ${network_value} ===\033[0m"

  echo -e "\n\033[1m=== RUNNING RPC NODE ===\033[0m\n"

  echo -e "1. Start the evmapp node:"

  echo -e "\n\033[1mdocker compose -f ${DEPLOYMENT_DIR}/docker-compose.yml up -d\033[0m"

  echo -e "\n\033[1m========================\033[0m\n"
fi

exit 0
