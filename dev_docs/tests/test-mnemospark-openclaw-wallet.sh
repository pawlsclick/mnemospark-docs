#!/usr/bin/env bash

set -euo pipefail

echo "[wallet-coexistence] Verifying mnemospark and OpenClaw/ClawRouter wallet separation"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "[wallet-coexistence] ERROR: openclaw CLI not found on PATH. Run install-openclaw.sh first."
  exit 1
fi

if ! command -v mnemospark >/dev/null 2>&1; then
  echo "[wallet-coexistence] ERROR: mnemospark CLI not found on PATH. Run install-mnemospark.sh first."
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

blockrun_wallet="${tmp_dir}/blockrun-wallet.key"
mnemospark_wallet="${tmp_dir}/mnemospark-wallet.key"

printf 'DUMMY_BLOCKRUN_WALLET' > "${blockrun_wallet}"

export BLOCKRUN_WALLET_KEY="${blockrun_wallet}"
export MNEMOSPARK_WALLET_KEY="${mnemospark_wallet}"

before_checksum="$(sha256sum "${blockrun_wallet}" | awk '{print $1}')"

echo "[wallet-coexistence] Running mnemospark wallet command"
if ! mnemospark wallet; then
  echo "[wallet-coexistence] ERROR: mnemospark wallet command failed"
  exit 1
fi

after_checksum="$(sha256sum "${blockrun_wallet}" | awk '{print $1}')"

if [[ "${before_checksum}" != "${after_checksum}" ]]; then
  echo "[wallet-coexistence] ERROR: mnemospark wallet modified BLOCKRUN_WALLET_KEY (${blockrun_wallet})"
  exit 1
fi

if [[ ! -f "${mnemospark_wallet}" ]]; then
  echo "[wallet-coexistence] ERROR: mnemospark wallet did not create or use MNEMOSPARK_WALLET_KEY at ${mnemospark_wallet}"
  exit 1
fi

echo "[wallet-coexistence] SUCCESS: mnemospark wallet uses MNEMOSPARK_WALLET_KEY and leaves BLOCKRUN_WALLET_KEY untouched"

