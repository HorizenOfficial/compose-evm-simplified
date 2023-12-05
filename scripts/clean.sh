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
  "ENV_FILE"
  "EVMAPP_DATA_VOL"
  "EVMAPP_SNARK_KEYS_VOL"
)

for var in "${vars_to_check[@]}"; do
  check_env_var "${var}"
  export "${var}"
done

# Checking if .env file exist and sourcing
env_file_exist "${ROOT_DIR}/${ENV_FILE}"
SCNODE_ROLE="$(grep 'SCNODE_ROLE=' "${ROOT_DIR}/${ENV_FILE}" | cut -d '=' -f2)" || { echo "SCNODE_ROLE value is wrong. Check ${ROOT_DIR}/${ENV_FILE} file"; exit 1; }
compose_project_name="$(grep 'COMPOSE_PROJECT_NAME=' "${ROOT_DIR}/${ENV_FILE}" | cut -d '=' -f2)" || { echo "COMPOSE_PROJECT_NAME value is wrong. Check ${ROOT_DIR}/${ENV_FILE} file"; exit 1; }
if [ -z "${SCNODE_ROLE:-}" ]; then
  fn_die "SCNODE_ROLE must be set in ${ROOT_DIR}/${ENV_FILE} file. Please run init.sh script first or populate all the variables in ${ROOT_DIR}/${ENV_FILE} file"
fi
select_compose_file

######
# Cleanup
######
cd "${ROOT_DIR}"

# Getting user's approval before cleanup
read -rp "This action will erase all the ${CONTAINER_NAME} node's data including your local wallet if present. Do you still want to proceed (y/n)? " REPLY
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "\nExiting ..."
  exit 1
fi

# Deleting resources
if [ -n "$(docker ps -q -f status=running -f name="${CONTAINER_NAME}")" ]; then
  echo "" && echo "=== Stopping ${CONTAINER_NAME} node ===" && echo ""
  $COMPOSE_CMD -f ${compose_file} down
else
  echo "" && echo "=== ${CONTAINER_NAME} node is not running. Nothing to stop ... ===" && echo ""
fi

# Cleaning up Sidechain node docker volumes if exist
if docker volume inspect "${compose_project_name}_${EVMAPP_DATA_VOL}" &>/dev/null; then
  echo "" && echo "=== Deleting ${EVMAPP_DATA_VOL} volume ===" && echo ""
  docker volume rm "${compose_project_name}_${EVMAPP_DATA_VOL}" || { echo "Error: could not delete ${compose_project_name}_${EVMAPP_DATA_VOL} for some reason. Can not proceed any further.  Exiting ..."; exit 1; }
else
  echo "" && echo "=== ${compose_project_name}_${EVMAPP_DATA_VOL} volume does not exist. Nothing to delete ... ===" && echo ""
fi

if docker volume inspect "${compose_project_name}_${EVMAPP_SNARK_KEYS_VOL}" &>/dev/null; then
  echo "" && echo "=== Deleting ${EVMAPP_SNARK_KEYS_VOL} volume ===" && echo ""
  docker volume rm "${compose_project_name}_${EVMAPP_SNARK_KEYS_VOL}" || { echo "Error: could not delete ${compose_project_name}_${EVMAPP_SNARK_KEYS_VOL} for some reason. Can not proceed any further.  Exiting ..."; exit 1; }
else
  echo "" && echo "=== ${compose_project_name}_${EVMAPP_SNARK_KEYS_VOL} volume does not exist. Nothing to delete ... ===" && echo ""
fi

# Bring env file back to defaults
sed -i "s/SCNODE_NET_NODENAME=.*/SCNODE_NET_NODENAME=/g" "${ROOT_DIR}/${ENV_FILE}"
sed -i "s/SCNODE_WALLET_SEED=.*/SCNODE_WALLET_SEED=/g" "${ROOT_DIR}/${ENV_FILE}"


######
# The END
######
echo "" && echo "=== Done ===" && echo ""
exit 0
