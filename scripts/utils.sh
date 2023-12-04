#!/bin/bash
# shellcheck disable=SC2120
ROOT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
CALLER=""
CONTAINER_NAME="${CONTAINER_NAME:-evmapp}"
EVMAPP_DATA_VOL="${EVMAPP_DATA_VOL:-evmapp-data}"
EVMAPP_SNARK_KEYS_VOL="${EVMAPP_SNARK_KEYS_VOL:-evmapp-snark-keys}"
ENV_FILE='.env'
compose_file=""

export ROOT_DIR CALLER CONTAINER_NAME ENV_FILE EVMAPP_DATA_VOL EVMAPP_SNARK_KEYS_VOL

# Functions
fn_die() {
  echo -e "$1" >&2
  exit "${2:-1}"
}

have_pwgen () {
  [ "${1:-}" = "usage" ] && return
  command -v pwgen &> /dev/null || { echo "${FUNCNAME[0]} error: 'pwgen' is required to run this script, install with 'sudo apt-get install pwgen'."; exit 1; }
}

have_docker () {
  [ "${1:-}" = "usage" ] && return
  command -v docker &> /dev/null || { echo "${FUNCNAME[0]} error: 'docker' is required to run this script, see installation instructions at 'https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository'."; exit 1; }
}

have_jq () {
  [ "${1:-}" = "usage" ] && return
  command -v jq &> /dev/null || { echo "${FUNCNAME[0]} error: 'jq' is required to run this script, install with 'sudo apt-get install jq'."; exit 1; }
}

have_compose_v2 () {
  [ "${1:-}" = "usage" ] && return
  [ -n "${COMPOSE_CMD:-}" ] && return
  have_docker
  ( docker-compose version 2>&1 | grep -q v2 || docker compose version 2>&1 | grep -q v2 ) || { echo "${FUNCNAME[0]} error: 'docker-compose' or 'docker compose' v2 is required to run this script, see installation instructions at 'https://docs.docker.com/compose/install/other/'."; exit 1; }
  COMPOSE_CMD="$(docker-compose version 2>&1 | grep -q v2 && echo 'docker-compose' || echo 'docker compose')"
  export COMPOSE_CMD
}

select_compose_file () {
  if [ ${SCNODE_ROLE:-} = "forger" ]; then
    compose_file=docker-compose-forger.yml
  else
    compose_file=docker-compose-simple.yml
  fi
}

check_env_var () {
  local usage="Check if required environmental variable is empty and produce an error - usage: ${CALLER}${FUNCNAME[0]} {env_var_name}"
  [ "${1:-}" = "usage" ] && echo "${usage}" && return
  [ "$#" -ne 1 ] && { echo -e "${FUNCNAME[0]} error: function requires exactly one argument.\n\n${usage}"; exit 1;}

  local var="${1}"
  if [ -z "${!var:-}" ]; then
    echo "Error: Environment variable ${var} is required. Exiting ..."
    sleep 5
    exit 1
  fi
}

env_file_exist () {
  local path_to_envfile="${1}"
  local usage="Check if ${path_to_envfile} exists under project's root directory - usage: ${CALLER}${FUNCNAME[0]} {path_to_envfile}"
  [ "${1:-}" = "usage" ] && echo "${usage}" && return
  [ "$#" -ne 1 ] && { echo -e "${FUNCNAME[0]} error: function requires exactly one argument.\n\n${usage}"; exit 1;}

  if ! [ -f "${path_to_envfile}" ]; then
    fn_die "${path_to_envfile} file is missing. Script will not be able to run.  Exiting..."
  fi
}

scnode_start_check() {
  i=0
  while [ "$(docker inspect "${CONTAINER_NAME}" 2>&1 | jq -rc '.[].State.Status' 2>&1)" != "running" ]; do
    sleep 5
    i="$((i+1))"
    if [ "$i" -gt 48 ]; then
      echo "Error: ${CONTAINER_NAME} container did not start within 4 minutes."
      exit 1
    fi
  done

  i=0
  while [ "$($COMPOSE_CMD exec "${CONTAINER_NAME}" gosu user curl -Isk -o /dev/null -w '%{http_code}' -m 10 -X POST "http://127.0.0.1:${SCNODE_REST_PORT}/block/best" -H 'accept: application/json' -H 'Content-Type: application/json')" -ne 200 ]; do
    echo "Waiting for ${CONTAINER_NAME} container and/or application to be ready."
    sleep 10
    i="$((i+1))"
    if [ "$i" -gt 90 ]; then
      fn_die "Error: ${CONTAINER_NAME} container and/or application did not start within 15 minutes."
    fi
  done
}
