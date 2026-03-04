#!/usr/bin/env bash
set -euo pipefail

echo "[per-job] OpenClaw + mnemospark test setup"

# Sanity check: Node + npm
node --version
npm --version

# Sanity check: OpenClaw from snapshot
openclaw --version

# Start gateway in background for tests (if not already running)
if ! pgrep -f "openclaw gateway" >/dev/null 2>&1; then
  echo "[per-job] Starting OpenClaw gateway on port 18789..."
  openclaw gateway --port 18789 --verbose >/tmp/openclaw-gateway.log 2>&1 &
  echo $! > /tmp/openclaw-gateway.pid
  sleep 5
fi

echo "[per-job] Setup complete."

