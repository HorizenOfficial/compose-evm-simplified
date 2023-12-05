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
  fn_die "The stack was not yet initialized. Run init.sh script first. There is nothing to start.  Exiting ..."
fi


######
# Node start
######
cd "${ROOT_DIR}"

if [ -n "$(docker ps -q -f status=running -f name="${CONTAINER_NAME}")" ]; then
  fn_die "${CONTAINER_NAME} node is already running. Nothing to start.  Exiting ..."
elif [ -z "$(docker ps -q -f status=running -f name="${CONTAINER_NAME}")" ]; then
  echo "" && echo "=== Starting ${CONTAINER_NAME} node ===" && echo ""

  $COMPOSE_CMD -f ${compose_file} up -d
fi

# Making sure scnode is up and running
scnode_start_check


######
# The END
######
echo "" && echo "=== Done ===" && echo ""
exit 0
