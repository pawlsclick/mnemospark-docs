#!/usr/bin/env bash
set -euo pipefail

# Ensure global npm bin is on PATH for future shells
export PATH="$HOME/.npm-global/bin:$PATH"

# Optional: move global installs out of /usr/local if you prefer non-root
# npm config set prefix "$HOME/.npm-global"

# Install OpenClaw CLI globally into the snapshot
npm install -g openclaw@latest