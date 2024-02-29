#!/bin/bash

set -eEuo pipefail

# This script is used to download and extract the blockchain data from a seed node.

# Select datadir
datadir="$HOME/.zen"

# Detect network
if grep -q "testnet=1" "$HOME/.zen/zen.conf" <(echo "${OPTS:-}"); then
  datadir+="/testnet3"
fi

# Check if script needs to be run
if [ "${FORCE_RESEED:-false}" = "true" ]; then
  echo "FORCE_RESEED is true. Removing seed lock and complete files."
  [ -f "${datadir}/.seed.lock" ] && rm -f "${datadir}/.seed.lock"
  [ -f "${datadir}/.seed.complete" ] && rm -f "${datadir}/.seed.complete"
  [ -d "${datadir}/blocks" ] && rm -rf "${datadir}/blocks"
  [ -d "${datadir}/chainstate" ] && rm -rf "${datadir}/chainstate"
  [ -f "${datadir}/*.tgz" ] && rm -f "${datadir}/*.tgz"
elif [ -f "${datadir}/.seed.complete" ]; then
  echo "'.seed.complete' file exists. Skipping seed step."
  exit 0
elif [ "${USE_SEED_FILE:-false}" = "false" ]; then
  echo "USE_SEED_FILE is false. Skipping seed step."
  touch "${datadir}/.seed.complete"
  exit 0
elif [ -d "${datadir}/blocks" ] && [ "$(ls -A "${datadir}"/blocks)" ]; then
  echo "'blocks' directory exist and is not empty. Skipping seed step."
  touch "${datadir}/.seed.complete"
  exit 0
elif [ -d "${datadir}/chainstate" ] && [ "$(ls -A "${datadir}"/chainstate)" ]; then
  echo "'chainstate' directory exist and is not empty. Skipping seed step."
  touch "${datadir}/.seed.complete"
  exit 0
fi

# Functions
download_and_extract_seed() {
  local retries=3

  # Create a lock file
  touch "${datadir}/.seed.lock"

  # Download loop
  for ((i = 1; i <= retries; i++)); do
    echo "Download attempt $i of $retries"

    if ! aria2c -x 1 -s 1 -d "${datadir}" "${SEED_TAR_GZ_URL}" 2>/dev/null; then
      echo "Download failed on attempt $i"
      if ((i == retries)); then
        echo "All download attempts failed. Exiting."
        rm "${datadir}/.seed.lock"
        exit 0
      fi
    else
      echo "Download succeeded"
      break
    fi
  done

  # Extraction loop
  for ((i = 1; i <= retries; i++)); do
    echo "Extraction attempt $i of $retries"

    if ! tar -xzf "${datadir}/$(basename "${SEED_TAR_GZ_URL}")" -C "${datadir}"; then
      echo "Extraction failed on attempt $i"

      # Empty the blocks and chainstate directories
      rm -rf "${datadir}/blocks"/*
      rm -rf "${datadir}/chainstate"/*

      if ((i == retries)); then
        echo "All extraction attempts failed. Removing directories and exiting."
        rm -rf "${datadir}/blocks"
        rm -rf "${datadir}/chainstate"
        rm -f "${datadir}/$(basename "${SEED_TAR_GZ_URL}")"
        rm "${datadir}/.seed.lock"
        exit 0
      fi
    else
      echo "Extraction succeeded"
      break
    fi
  done

  # If both steps succeeded, remove the lock file and the downloaded tar file
  rm -f "${datadir}/$(basename "${SEED_TAR_GZ_URL}")"
  rm "${datadir}/.seed.lock"
  touch "${datadir}/.seed.complete"
}

import_seed() {
  local retries=3

  # Create a lock file
  touch "${datadir}/.seed.lock"

  # Import loop
  for ((i = 1; i <= retries; i++)); do
    echo "Import attempt $i of $retries"

    if ! curl -L "${SEED_TAR_GZ_URL}" | tar -xzf - -C "${datadir}"; then
      echo "Import failed on attempt $i"
      if ((i == retries)); then
        echo "All import attempts failed. Exiting."
        rm "${datadir}/.seed.lock"
        exit 0
      fi
    else
      echo "Import succeeded"
      break
    fi
  done

  # If the import succeeded, remove the lock file and return
  rm "${datadir}/.seed.lock"
  touch "${datadir}/.seed.complete"
}

content_length=$(curl -s -I -X HEAD -H "Range: bytes=0-1023" "${SEED_TAR_GZ_URL}" | grep content-length | awk '{print $2}' | tr -d '\r')
extended_content_length=$((content_length + content_length / 10))
total_size=$((2 * extended_content_length))

echo "Content length: ${content_length} bytes"
echo "Extended content length: ${extended_content_length} bytes"
echo "Total size: ${total_size} bytes"

datadir_available_space=$(df -P "${datadir}" | awk 'NR==2 {print $4}')
datadir_available_space_bytes=$((datadir_available_space * 1024))
echo "Available space in ${datadir}: ${datadir_available_space_bytes} bytes"

if [ "${datadir_available_space_bytes}" -lt ${extended_content_length} ]; then
  echo "Error: Not enough space in ${datadir} to run the zend node."
  exit 1
fi

if [ "${datadir_available_space_bytes}" -ge ${total_size} ]; then
  download_and_extract_seed "${datadir}" "${SEED_TAR_GZ_URL}"
else
  import_seed "${datadir}" "${SEED_TAR_GZ_URL}"
fi

chown -fR "$(stat -c "%u:%g" "${datadir}")" "${datadir}"

exit 0
