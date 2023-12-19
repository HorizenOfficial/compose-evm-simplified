#!/bin/bash

set -Eeuo pipefail

if [ -z "${SEED_TAR_GZ_URL:-}" ]; then
  echo "SEED_TAR_GZ_URL is unset, nothing to do."
  exit 0
fi

datadir="$HOME/.zen"
# detect network
if grep -q "testnet=1" "$HOME/.zen/zen.conf" <(echo "${OPTS:-}"); then
  datadir+="/testnet3"
fi

if ! [ -f "${datadir}/.seed_done" ]; then
  echo "Importing seed from ${SEED_TAR_GZ_URL}"
  curl -L "${SEED_TAR_GZ_URL}" | tar -xzf - -C "${datadir}"
  touch "${datadir}/.seed_done"
fi

chown -fR "$(stat -c "%u:%g" "${datadir}")" "${datadir}"
