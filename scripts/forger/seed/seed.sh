#!/bin/bash

set -eEuo pipefail

# Select seed_dir
seed_dir="/mnt/seed"
blocks_dir="${seed_dir}/blocks"
chainstate_dir="${seed_dir}/chainstate"

# Select data_dir
data_dir="${HOME}/.zen"
# Detect network
if grep -q "testnet=1" "${HOME}/.zen/zen.conf" <(echo "${OPTS:-}"); then
  data_dir+="/testnet3"
fi

# Main
echo "Starting the seed process..."

# Check if blocks_dir or chainstate_dir does not exist or is empty
if [ ! -d "${blocks_dir}" ] || [ ! "$(ls -A "${blocks_dir}")" ] || [ ! -d "${chainstate_dir}" ] || [ ! "$(ls -A "${chainstate_dir}")" ]; then
  echo "Either ${blocks_dir} or ${chainstate_dir} seed directories do not exist or are empty. Nothing to seed. Exiting script."
  exit 0
fi

if [ "${FORCE_RESEED:-false}" = "true" ]; then
  echo "FORCE_RESEED is set to true. Removing seed lock file and preparing data directory for the seed process..."
  [ -f "${data_dir}/.seed.complete" ] && rm -f "${data_dir}/.seed.complete"
  [ -d "${data_dir}/blocks" ] && rm -rf "${data_dir}/blocks"
  [ -d "${data_dir}/chainstate" ] && rm -rf "${data_dir}/chainstate"
elif [ -f "${data_dir}/.seed.complete" ]; then
  echo "'${data_dir}/.seed.complete' file exists. Skipping seed step."
  exit 0
elif [ -d "${data_dir}/blocks" ] && [ "$(ls -A "${data_dir}"/blocks)" ]; then
  echo "'${data_dir}/blocks' directory exists and is not empty. Skipping seed step."
  touch "${data_dir}/.seed.complete"
  exit 0
elif [ -d "${data_dir}/chainstate" ] && [ "$(ls -A "${data_dir}"/chainstate)" ]; then
  echo "'${data_dir}/chainstate' directory exists and is not empty. Skipping seed step."
  touch "${data_dir}/.seed.complete"
  exit 0
fi

# Move blocks and chainstate directories to the data directory
if [ -d "${blocks_dir}" ]; then
  echo "Moving blocks directory to the data directory..."
  mv "${blocks_dir}" "${data_dir}"
fi

if [ -d "${chainstate_dir}" ]; then
  echo "Moving chainstate directory to the data directory..."
  mv "${chainstate_dir}" "${data_dir}"
fi

echo "Creating .seed.complete file..."
touch "${data_dir}/.seed.complete"

# Fix ownership of the created files/folders
# find -writrable is preferred over chown -R as :ro bind mounts could be present
# Trailing / after ${data_dir} is important to follow the symlink
owner="$(stat -c "%u:%g" "${data_dir}/")"
find "${data_dir}/" -writable -print0 | xargs -0 -I{} -P64 -n1 chown -f "${owner}" "{}"

echo "Seed process completed successfully."

exit 0
