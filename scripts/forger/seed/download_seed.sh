#!/bin/bash

# This script is used to download and extract the blockchain data from a seed file.
set -eEuo pipefail

command -v aria2c &>/dev/null || {
  echo "${FUNCNAME[0]} Error: 'aria2c' is required to run this script, see installation instructions at 'https://github.com/aria2/aria2/releases/tag/release-1.37.0'."
  exit 1
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
deployment_dir="$(readlink -f "${script_dir}/../")"
seed_dir="${deployment_dir}/seed"
env_file="${deployment_dir}/.env"

# shellcheck source=../.env
source "${env_file}"

remote_file="${ZEN_SEED_TAR_GZ_URL}"
filename=$(basename "${remote_file}")

content_length=$(curl -s -I -X HEAD -H "Range: bytes=0-1023" "${remote_file}" | grep content-length | awk '{print $2}' | tr -d '\r')
extended_content_length=$((content_length + content_length / 10))
total_size=$((2 * extended_content_length))

{
  echo "Seed file size: ${content_length} bytes"
  echo "Minimal required storage size: ${extended_content_length} bytes"
  echo "Recommended storage size: ${total_size} bytes"
} >>"${seed_dir}/seed.log"

seed_dir_available_space=$(df -P "${seed_dir}" | awk 'NR==2 {print $4}')
seed_dir_available_space_bytes=$((seed_dir_available_space * 1024))
echo "Available space in ${seed_dir}: ${seed_dir_available_space_bytes} bytes" >>"${seed_dir}/seed.log"

if [ "${seed_dir_available_space_bytes}" -lt ${extended_content_length} ]; then
  echo "Error: Not enough space in ${seed_dir} to run the zend node." >>"${seed_dir}/seed.log"
  exit 1
fi

if [ "${seed_dir_available_space_bytes}" -ge ${total_size} ]; then
  echo "There is enough storage to download and extract the seed file." >>"${seed_dir}/seed.log"
  echo "Retrieving (aria2): ${remote_file}" >>"${seed_dir}/seed.log"

  aria2c \
    --dir="${seed_dir}" \
    --out="${filename}" \
    --continue=true \
    --max-tries=3 \
    --retry-wait=2 \
    --split=4 \
    --max-connection-per-server=4 \
    --timeout=90 \
    --auto-save-interval=5 \
    --always-resume=false \
    --allow-overwrite=true \
    --download-result=full \
    --summary-interval=10 \
    "${remote_file}" >>"${seed_dir}/seed.log" ||
    {
      echo -e "\nResume failed, downloading $filename from scratch.\n" >>"${seed_dir}/seed.log" &&
        aria2c \
          --dir="${seed_dir}" \
          --out="${filename}" \
          --continue=false \
          --remove-control-file=true \
          --max-tries=3 \
          --timeout=30 \
          --always-resume=false \
          --allow-overwrite=true \
          --download-result=full \
          --summary-interval=10 \
          "${remote_file}" >>"${seed_dir}/seed.log"
    }

  echo "Extracting seed file" >>"${seed_dir}/seed.log"

  tar -xzf "${seed_dir}/${filename}" -C "${seed_dir}" >>"${seed_dir}/seed.log"

  echo "Seed file extraction succeeded" >>"${seed_dir}/seed.log"

  echo "Removing seed file" >>"${seed_dir}/seed.log"

  rm -f "${seed_dir}/${filename}"

else
  echo "There is no enough storage to download and extract the seed file. Extracting directly from remote." >>"${seed_dir}/seed.log"
  retries=3

  # Extraction loop
  for ((i = 1; i <= retries; i++)); do
    echo "Seed file extraction attempt $i of $retries" >>"${seed_dir}/seed.log"

    rm -rf "${seed_dir}/blocks"/*
    rm -rf "${seed_dir}/chainstate"/*

    if ! curl -L "${remote_file}" | tar -xzf - -C "${seed_dir}" >>"${seed_dir}/seed.log"; then
      echo "Seed file extraction failed on attempt $i" >>"${seed_dir}/seed.log"
      if ((i == retries)); then
        echo "Error: all seed file extraction attempts failed. Removing directories and exiting." >>"${seed_dir}/seed.log"
        rm -rf "${seed_dir}/blocks"
        rm -rf "${seed_dir}/chainstate"
        exit 0
      fi
    else
      echo "Seed file extraction succeeded" >>"${seed_dir}/seed.log"
      break
    fi
  done
  echo "Seed process succeeded. The node will start syncing from the imported data." >>"${seed_dir}/seed.log"
fi

echo "Seed process completed successfully. Exiting script." >>"${seed_dir}/seed.log"

exit 0
