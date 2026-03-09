#!/usr/bin/env bash
#
# Live-patch mnemospark proxy to add backendConfigured to /health response.
#
# Patches the built dist files (index.js and cli.js) in place so that
# GET /health returns backendConfigured: true|false without rebuilding.
#
# Usage:
#   ./live-patch-proxy-health-backend-configured.sh [MNEMOSPARK_ROOT]
#
# Default MNEMOSPARK_ROOT: ~/.openclaw/extensions/mnemospark
# (e.g. after openclaw plugins install mnemospark)
#
# Restart the gateway (or proxy) after patching for the change to take effect.
#

set -e

MNEMOSPARK_ROOT="${1:-$HOME/.openclaw/extensions/mnemospark}"
DIST_INDEX="$MNEMOSPARK_ROOT/dist/index.js"
DIST_CLI="$MNEMOSPARK_ROOT/dist/cli.js"

patch_one() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Skip (not found): $file"
    return 0
  fi
  if grep -q "backendConfigured" "$file"; then
    echo "Already patched: $file"
    return 0
  fi
  # Use Node to do the replacement (real newlines in built JS)
  node -e '
    const fs = require("fs");
    const path = process.argv[1];
    let content = fs.readFileSync(path, "utf8");
    const old = "        wallet: account.address\n      };";
    const new_ = "        wallet: account.address,\n        backendConfigured: MNEMOSPARK_BACKEND_API_BASE_URL.trim().length > 0\n      };";
    if (!content.includes("wallet: account.address")) {
      console.error("Pattern not found in " + path);
      process.exit(1);
    }
    if (content.includes("backendConfigured")) {
      console.log("Already patched: " + path);
      process.exit(0);
    }
    const before = content;
    content = content.replace(old, new_);
    if (content === before) {
      console.error("Replace had no effect (pattern may have different whitespace in " + path + ")");
      process.exit(1);
    }
    fs.writeFileSync(path, content);
    console.log("Patched: " + path);
  ' "$file"
}

echo "Patching mnemospark at: $MNEMOSPARK_ROOT"
patch_one "$DIST_INDEX"
patch_one "$DIST_CLI"
echo "Done. Restart the OpenClaw gateway (or mnemospark proxy) for the change to take effect."
