#!/usr/bin/env bash
# Update .company submodule to remote in mnemospark and mnemospark-backend.
# Run from any directory.

set -e

MNEMOSPARK_DIR="/Users/woodrowbrown/Projects/mnemospark"
MNEMOSPARK_BACKEND_DIR="/Users/woodrowbrown/Projects/mnemospark-backend"

echo "Updating .company submodule in mnemospark..."
cd "$MNEMOSPARK_DIR"
git submodule update --remote .company

echo "Updating .company submodule in mnemospark-backend..."
cd "$MNEMOSPARK_BACKEND_DIR"
git submodule update --remote .company

echo "Done."
