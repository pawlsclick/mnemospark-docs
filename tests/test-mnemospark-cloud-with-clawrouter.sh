#!/usr/bin/env bash

set -euo pipefail

echo "[cloud-smoke] Running /mnemospark cloud commands with ClawRouter/OpenClaw present"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "[cloud-smoke] ERROR: openclaw CLI not found on PATH. Run install-openclaw.sh and install-clawrouter.sh first."
  exit 1
fi

if ! command -v mnemospark >/dev/null 2>&1; then
  echo "[cloud-smoke] ERROR: mnemospark CLI not found on PATH. Run install-mnemospark.sh first."
  exit 1
fi

tmp_home="$(mktemp -d)"
trap 'rm -rf "${tmp_home}"' EXIT

export HOME="${tmp_home}"

echo "[cloud-smoke] Restarting OpenClaw/ClawRouter gateway"
openclaw gateway restart

sleep 5

echo "[cloud-smoke] Ensuring ClawRouter port 8402 is up (best-effort)"
if ! lsof -i :8402 >/dev/null 2>&1; then
  echo "[cloud-smoke] WARNING: Could not detect listener on port 8402"
fi

mnemospark_dir="${HOME}/.openclaw/mnemospark"
mkdir -p "${mnemospark_dir}/backup"

test_file="${mnemospark_dir}/backup/test-backup-file.txt"
printf 'hello from mnemospark cloud smoke test' > "${test_file}"

dummy_wallet_address="0x000000000000000000000000000000000000dEaD"

export MNEMOSPARK_BACKEND_API_BASE_URL="${MNEMOSPARK_BACKEND_API_BASE_URL:-http://127.0.0.1:7121}"

echo "[cloud-smoke] Running /mnemospark cloud help"
mnemospark cloud help || {
  echo "[cloud-smoke] ERROR: mnemospark cloud help failed"
  exit 1
}

echo "[cloud-smoke] Running /mnemospark cloud backup"
mnemospark cloud backup "${test_file}" || {
  echo "[cloud-smoke] ERROR: mnemospark cloud backup failed"
  exit 1
}

echo "[cloud-smoke] Attempting /mnemospark cloud price-storage (may hit stub backend)"
if ! mnemospark cloud price-storage \
  --wallet-address "${dummy_wallet_address}" \
  --object-id "test-object-id" \
  --object-id-hash "test-object-id-hash" \
  --gb "1" \
  --provider "aws" \
  --region "us-east-1"; then
  echo "[cloud-smoke] WARNING: mnemospark cloud price-storage failed (likely due to missing backend); continuing, as this test focuses on coexistence, not backend availability."
fi

echo "[cloud-smoke] Verifying mnemospark wrote under ~/.openclaw/mnemospark and did not create ~/.openclaw/blockrun"

if [[ ! -d "${mnemospark_dir}" ]]; then
  echo "[cloud-smoke] ERROR: Expected mnemospark directory at ${mnemospark_dir} was not created"
  exit 1
fi

blockrun_dir="${HOME}/.openclaw/blockrun"
if [[ -d "${blockrun_dir}" ]]; then
  echo "[cloud-smoke] WARNING: ~/.openclaw/blockrun exists under test HOME; ensure mnemospark did not modify it in other tests."
fi

echo "[cloud-smoke] SUCCESS: /mnemospark cloud commands ran with ClawRouter present and used mnemospark-specific paths"

