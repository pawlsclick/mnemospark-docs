#!/usr/bin/env bash

# This goes between install-openclaw.sh and per-job-openclaw-setup.sh 
#in the execution order. It builds the TypeScript source into dist/ 
# and runs npm link to make the mnemospark binary available globally on PATH.

set -euo pipefail

echo "[setup] Installing mnemospark from local workspace"

# Build the project
echo "[setup] Building mnemospark..."
npm run build

# Link globally so 'mnemospark' CLI and 'npx mnemospark' resolve locally
echo "[setup] Linking mnemospark globally..."
npm link

# Verify
echo "[setup] Verifying..."
mnemospark --version

echo "[setup] mnemospark installed and available."