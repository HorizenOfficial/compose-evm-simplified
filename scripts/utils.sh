#!/bin/bash

# Functions
fn_die() {
  echo -e "\n\033[0;31m\033[1m${1}\033[0m\n" >&2
  exit "${2:-1}"
}

verify_required_commands() {

  command -v pwgen &>/dev/null || fn_die "${FUNCNAME[0]} Error: 'pwgen' is required to run this script, install with 'sudo apt-get install pwgen' or 'brew install pwgen'."

  command -v jq &>/dev/null || fn_die "${FUNCNAME[0]} Error: 'jq' is required to run this script, see installation instructions at 'https://jqlang.github.io/jq/download/'."

  command -v docker &>/dev/null || fn_die "${FUNCNAME[0]} Error: 'docker' is required to run this script, see installation instructions at 'https://docs.docker.com/engine/install/'."

  (docker compose version 2>&1 | grep -q v2) || fn_die "${FUNCNAME[0]} Error: 'docker compose' v2 is required to run this script, see installation instructions at 'https://docs.docker.com/compose/install/'."

  if [ "$(uname)" = "Darwin" ]; then
    command -v gsed &>/dev/null || fn_die "${FUNCNAME[0]} Error: 'gnu-sed' is required to run this script in MacOS environment, see installation instructions at 'https://formulae.brew.sh/formula/gnu-sed'. Make sure to add it to your PATH."
  fi
}

check_env_var() {
  local usage="Check if required environmental variable is empty and produce an error - usage: ${FUNCNAME[0]} {env_var_name}"
  [ "${1:-}" = "usage" ] && echo "${usage}" && return
  [ "$#" -ne 1 ] && {
    fn_die "${FUNCNAME[0]} error: function requires exactly one argument.\n\n${usage}"
  }

  local var="${1}"
  if [ -z "${!var:-}" ]; then
    fn_die "Error: Environment variable ${var} is required. Exiting ..."
  fi
}

check_required_variables() {
  TO_CHECK=(
    "COMPOSE_PROJECT_NAME"
    "INTERNAL_NETWORK_SUBNET"
    "EVMAPP_TAG"
    "EVMAPP_CONTAINER_NAME"
    "EVMAPP_IP_ADDRESS"
    "SCNODE_ROLE"
    "SCNODE_FORGER_ENABLED"
    "SCNODE_ALLOWED_FORGERS"
    "SCNODE_FORGER_RESTRICT"
    "SCNODE_REMOTE_KEY_MANAGER_ENABLED"
    "SCNODE_CERT_SIGNING_ENABLED"
    "SCNODE_CERT_SUBMITTER_ENABLED"
    "SCNODE_CERT_SIGNERS_MAXPKS"
    "SCNODE_CERT_SIGNERS_THRESHOLD"
    "SCNODE_CERT_SIGNERS_PUBKEYS"
    "SCNODE_CERT_MASTERS_PUBKEYS"
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
    "SCNODE_NET_MAX_IN_CONNECTIONS"
    "SCNODE_NET_MAX_OUT_CONNECTIONS"
    "SCNODE_NET_API_LIMITER_ENABLED"
    "SCNODE_NET_SLOW_MODE"
    "SCNODE_NET_REBROADCAST_TXS"
    "SCNODE_NET_HANDLING_TXS"
    "SCNODE_USER_ID"
    "SCNODE_GRP_ID"
    "SCNODE_WS_ZEN_FQDN"
    "SCNODE_WS_SERVER_PORT"
    "SCNODE_WS_CLIENT_ENABLED"
    "SCNODE_WS_SERVER_ENABLED"
    "SCNODE_WALLET_SEED"
    "SCNODE_WALLET_MAXTX_FEE"
    "SCNODE_LOG_FILE_LEVEL"
    "SCNODE_LOG_CONSOLE_LEVEL"
  )

  if [ "${SCNODE_ROLE}" = "forger" ]; then
    TO_CHECK+=(
      "SCNODE_FORGER_MAXCONNECTIONS"
      "ZEND_TAG"
      "ZEND_CONTAINER_NAME"
      "ZEND_IP_ADDRESS"
      "ZEN_PORT"
      "ZEN_RPC_USER"
      "ZEN_RPC_PASSWORD"
      "ZEN_RPC_PORT"
      "ZEN_WS_PORT"
      "ZEN_RPC_ALLOWIP_PRESET"
      "ZEN_EXTERNAL_IP"
      "ZEN_OPTS"
      "ZEN_LOG"
      "ZEN_LOCAL_USER_ID"
      "ZEN_LOCAL_GRP_ID"
    )
  fi

  for var in "${TO_CHECK[@]}"; do
    check_env_var "${var}"
  done
}

scnode_start_check() {
  i=0
  while [ "$(docker inspect "${EVMAPP_CONTAINER_NAME}" 2>&1 | jq -rc '.[].State.Status' 2>&1)" != "running" ]; do
    sleep 10
    i="$((i + 1))"
    if [ "$i" -eq 6 ]; then
      fn_die "Error: ${EVMAPP_CONTAINER_NAME} container is not running."
    fi
  done

  i=0
  while [ "$(docker exec "${EVMAPP_CONTAINER_NAME}" gosu user curl -Isk -o /dev/null -w '%{http_code}' -m 10 -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/block/best" -H 'accept: application/json' -H 'Content-Type: application/json')" -ne 200 ]; do
    echo "Waiting for ${EVMAPP_CONTAINER_NAME} container and/or application to be ready."
    sleep 10
    i="$((i + 1))"
    if [ "$i" -eq 6 ]; then
      fn_die "Error: ${EVMAPP_CONTAINER_NAME} container and/or application is not reachable."
    fi
  done
}

# Function to strip 0x prefix
strip_0x() {
  local usage="Check validity of etherium wallet address - usage: ${FUNCNAME[0]} {eth_wallet_address}"
  [ "${1:-}" = "usage" ] && echo "${usage}" && return
  [ "$#" -ne 1 ] && {
    fn_die "${FUNCNAME[0]} error: function requires exactly one argument.\n\n${usage}"
  }

  local input="${1}"
  local eth_address_regex="[0-9a-fA-F]{40}$"

  # Check if the input starts with "0x"
  if [[ "${input}" =~ ^0x${eth_address_regex} ]]; then
    # Remove the "0x" prefix
    echo "${input:2}"
  elif [[ "${input}" =~ ${eth_address_regex} ]]; then
    echo "${input}"
  else
    # If address is in the wrong format
    echo "invalid"
  fi
}
