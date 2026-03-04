#!/usr/bin/env bash

set -euo pipefail

echo "[shared-wallet] Verifying mnemospark can reuse a BlockRun wallet without modifying it"

if ! command -v mnemospark >/dev/null 2>&1; then
  echo "[shared-wallet] ERROR: mnemospark CLI not found on PATH. Run install-mnemospark.sh first."
  exit 1
fi

tmp_home="$(mktemp -d)"
trap 'rm -rf "${tmp_home}"' EXIT

export HOME="${tmp_home}"

blockrun_wallet="${HOME}/.openclaw/blockrun/wallet.key"
mkdir -p "$(dirname "${blockrun_wallet}")"
printf 'FAKE_BLOCKRUN_WALLET_FOR_MNEMOSPARK_TEST' > "${blockrun_wallet}"

unset MNEMOSPARK_WALLET_KEY

before_checksum="$(sha256sum "${blockrun_wallet}" | awk '{print $1}')"

echo "[shared-wallet] Running mnemospark wallet with legacy BlockRun wallet present"
if ! mnemospark wallet; then
  echo "[shared-wallet] ERROR: mnemospark wallet command failed when BlockRun wallet exists"
  exit 1
fi

after_checksum="$(sha256sum "${blockrun_wallet}" | awk '{print $1}')"

if [[ "${before_checksum}" != "${after_checksum}" ]]; then
  echo "[shared-wallet] ERROR: mnemospark wallet modified the legacy BlockRun wallet at ${blockrun_wallet}"
  exit 1
fi

mnemospark_dir="${HOME}/.openclaw/mnemospark"

if [[ ! -d "${mnemospark_dir}" ]]; then
  echo "[shared-wallet] WARNING: mnemospark did not create ${mnemospark_dir}; continuing, as long as BlockRun wallet is unchanged."
fi

echo "[shared-wallet] SUCCESS: mnemospark reuses or inspects BlockRun wallet without modifying it and keeps its own files under ~/.openclaw/mnemospark"

