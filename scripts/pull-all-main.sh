#!/usr/bin/env bash
# Pull latest main in mnemospark-docs, mnemospark, and mnemospark-backend.
# Run from mnemospark-docs (e.g. ./scripts/pull-all-main.sh or bash scripts/pull-all-main.sh).

set -e

MNEMOSPARK_DOCS="/Users/woodrowbrown/Projects/mnemospark-docs"
MNEMOSPARK="${MNEMOSPARK:-/Users/woodrowbrown/Projects/mnemospark}"
MNEMOSPARK_BACKEND="${MNEMOSPARK_BACKEND:-/Users/woodrowbrown/Projects/mnemospark-backend}"

pull_main() {
  local repo_dir="$1"
  local repo_name="$2"
  if [[ ! -d "$repo_dir" ]]; then
    echo "  Skip $repo_name: not found at $repo_dir"
    return 0
  fi
  echo "--- $repo_name ($repo_dir)"
  cd "$repo_dir"
  git fetch origin
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" != "main" ]]; then
    git checkout main
  fi
  git pull origin main --no-rebase
  echo "  Done."
}

echo "Pulling main in all three repos..."
pull_main "$MNEMOSPARK_DOCS" "mnemospark-docs"
pull_main "$MNEMOSPARK"      "mnemospark"
pull_main "$MNEMOSPARK_BACKEND" "mnemospark-backend"
echo "All done."
