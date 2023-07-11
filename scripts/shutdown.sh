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
scnode_rest_port="$(grep 'SCNODE_REST_PORT=' "${ROOT_DIR}/${ENV_FILE}" | cut -d '=' -f2)" || { echo "SCNODE_REST_PORT value is wrong. Check ${ROOT_DIR}/${ENV_FILE} file"; exit 1; }


######
# Node stop
######
cd "${ROOT_DIR}"

if [ -n "$(docker ps -q -f status=running -f name="${CONTAINER_NAME}")" ]; then
  echo "" && echo "=== Gracefully stopping ${CONTAINER_NAME} and removing containers ===" && echo ""

  docker update --restart=no "${CONTAINER_NAME}" &>/dev/null

  $COMPOSE_CMD exec "${CONTAINER_NAME}" gosu user curl -s -X POST "http://127.0.0.1:${scnode_rest_port}/node/stop" -H "accept: application/json" -H 'Content-Type: application/json' &>/dev/null
  sleep 5
else
  echo "" && echo "=== ${CONTAINER_NAME} node is not running.  Nothing to stop ... ===" && echo ""
fi

# Running docker compose down
$COMPOSE_CMD down


######
# The END
######
echo "" && echo "=== Done ===" && echo ""
exit 0
