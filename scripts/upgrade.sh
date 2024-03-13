#!/bin/bash

set -eEuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
source "${ROOT_DIR}"/scripts/utils.sh

verify_required_commands

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

DEPLOYMENT_DIR="${ROOT_DIR}/deployments/${role_value}/${network_value}"
ENV_FILE_TEMPLATE="${ROOT_DIR}/env/.env.${role_value}.${network_value}.template"
ENV_FILE="${DEPLOYMENT_DIR}/.env"

# Create a backup of .env file called .env.bk
echo -e "\n\033[1m=== Creating a backup of the ${ENV_FILE} file ===\033[0m"
cp "${ENV_FILE}" "${ENV_FILE}.bk"

# Define the auto update variables
auto_update_vars=(
  "EVMAPP_TAG"
  "ZEND_TAG"
  "ZEN_SEED_TAR_GZ_URL"
)

conditional_update_vars=(
  "ZEN_OPTS"
  "SCNODE_FORGER_MAXCONNECTIONS"
  "SCNODE_NET_MAX_IN_CONNECTIONS"
  "SCNODE_NET_MAX_OUT_CONNECTIONS"
  "SCNODE_LOG_FILE_LEVEL"
)

# Read the .env.template file line by line, skip blank lines and comments, store each of the other lines in an array
echo -e "\n\033[1m=== Reading ${ENV_FILE_TEMPLATE} file ===\033[0m"
while IFS= read -r line; do
  [ -z "${line}" ] && continue
  [ "${line:0:1}" = "#" ] && continue
  env_template_lines+=("${line}")
done <"${ENV_FILE_TEMPLATE}"

# Append new env vars to .env file
echo -e "\n\033[1m=== Appending new env vars to ${ENV_FILE} file ===\033[0m"
for line in "${env_template_lines[@]}"; do
  var_name=$(echo "${line}" | cut -d'=' -f1)
  if ! grep -q "^${var_name}=" "${ENV_FILE}"; then
    echo -e "\n${line}" >>"${ENV_FILE}"
  fi
done

# Update the values of the auto update variables
echo -e "\n\033[1m=== Updating the values of the auto update variables ===\033[0m"
for line in "${env_template_lines[@]}"; do
  var_name=$(echo "${line}" | cut -d'=' -f1)
  for item in "${auto_update_vars[@]}"; do
    if [[ "${item}" == "${var_name}" ]]; then
      sed -i "/^${var_name}=/c\\${line}" "${ENV_FILE}"
      break
    fi
  done
done

# Update the values of the conditional update variables if approved by the user
echo -e "\n\033[1m=== Updating the values of the conditional update variables ===\033[0m"
for line in "${env_template_lines[@]}"; do
  var_name=$(echo "${line}" | cut -d'=' -f1)
  for item in "${conditional_update_vars[@]}"; do
    if [[ "${item}" == "${var_name}" ]]; then
      if ! grep -q "^${line}" "${ENV_FILE}"; then
        echo -e "\nThe value of ${var_name} in the ${ENV_FILE} file is different from the value in the ${ENV_FILE_TEMPLATE} file."
        echo -e "${ENV_FILE} value: \033[1m$(grep "^${var_name}=" "${ENV_FILE}")\033[0m"
        echo -e "${ENV_FILE_TEMPLATE} value: \033[1m${line}\033[0m\n"
        read -rp "Would you like to update the value of ${var_name} in the ${ENV_FILE} file to the value from the ${ENV_FILE_TEMPLATE} file? ('yes' or 'no') " answer
        while [[ ! "${answer}" =~ ^(yes|no)$ ]]; do
          echo -e "\nError: The only allowed answers are 'yes' or 'no'. Try again...\n"
          read -rp "Would you like to update the value of ${var_name} in the ${ENV_FILE} file to the value from the ${ENV_FILE_TEMPLATE} file? ('yes' or 'no') " answer
        done
        if [ "${answer}" = "yes" ]; then
          sed -i "/^${var_name}=/c\\${line}" "${ENV_FILE}"
        fi
      fi
      break
    fi
  done
done

echo -e "\n\033[1m=== ${ENV_FILE} upgrade completed successfully ==="

echo -e "\n=== Please review the changes in the ${ENV_FILE} file, if there is anything wrong you can restore the backup file ${ENV_FILE}.bk ==="

echo -e "\n=== In order to apply the changes, run: "

echo -e "\ndocker compose -f ${ROOT_DIR}/deployments/${role_value}/${network_value}/docker-compose.yml down && docker compose -f ${ROOT_DIR}/deployments/${role_value}/${network_value}/docker-compose.yml up -d "

echo -e "\n===\033[0m"

exit 0
