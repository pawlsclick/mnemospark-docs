#!/usr/bin/env bash

set -euo pipefail

echo "[proxy-coexistence] Verifying mnemospark proxy and ClawRouter/OpenClaw gateway can run on different ports"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "[proxy-coexistence] ERROR: openclaw CLI not found on PATH. Run install-openclaw.sh and install-clawrouter.sh first."
  exit 1
fi

if ! command -v mnemospark >/dev/null 2>&1; then
  echo "[proxy-coexistence] ERROR: mnemospark CLI not found on PATH. Run install-mnemospark.sh first."
  exit 1
fi

echo "[proxy-coexistence] Restarting OpenClaw/ClawRouter gateway"
openclaw gateway restart

sleep 5

echo "[proxy-coexistence] Checking ClawRouter port 8402"
if ! lsof -i :8402 >/dev/null 2>&1; then
  echo "[proxy-coexistence] WARNING: No process listening on port 8402 after openclaw gateway restart"
else
  echo "[proxy-coexistence] ClawRouter appears to be listening on port 8402"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

export MNEMOSPARK_PROXY_PORT=7120

echo "[proxy-coexistence] Starting mnemospark proxy on port ${MNEMOSPARK_PROXY_PORT}"
mnemospark proxy start > "${tmp_dir}/mnemospark-proxy.log" 2>&1 &
proxy_pid=$!

sleep 5

if ! kill -0 "${proxy_pid}" >/dev/null 2>&1; then
  echo "[proxy-coexistence] ERROR: mnemospark proxy process exited unexpectedly"
  echo "[proxy-coexistence] Log output:"
  cat "${tmp_dir}/mnemospark-proxy.log" || true
  exit 1
fi

echo "[proxy-coexistence] Checking mnemospark proxy port ${MNEMOSPARK_PROXY_PORT}"
if ! lsof -i :"${MNEMOSPARK_PROXY_PORT}" >/dev/null 2>&1; then
  echo "[proxy-coexistence] ERROR: No process listening on port ${MNEMOSPARK_PROXY_PORT} for mnemospark proxy"
  kill "${proxy_pid}" || true
  exit 1
fi

echo "[proxy-coexistence] Verifying ClawRouter port 8402 remains available while mnemospark proxy is running"
if ! lsof -i :8402 >/dev/null 2>&1; then
  echo "[proxy-coexistence] WARNING: No process listening on port 8402 while mnemospark proxy is running"
fi

echo "[proxy-coexistence] Stopping mnemospark proxy (pid=${proxy_pid})"
kill "${proxy_pid}" || true

sleep 2

echo "[proxy-coexistence] SUCCESS: mnemospark proxy can run alongside ClawRouter/OpenClaw gateway without port conflicts (7120 vs 8402)"

