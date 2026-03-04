#!/usr/bin/env bash
set -euo pipefail

# Ensure global npm bin is on PATH for future shells
export PATH="$HOME/.npm-global/bin:$PATH"

# Install / update ClawRouter via official installer
curl -fsSL https://blockrun.ai/ClawRouter-update | bash

# Restart OpenClaw gateway so smart routing is active
openclaw gateway restart

