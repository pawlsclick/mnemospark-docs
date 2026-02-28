#!/usr/bin/env bash
# Update .company submodule to latest mnemospark-docs in mnemospark and
# mnemospark-backend, then commit and push the new submodule reference in each
# so GitHub and fresh clones stay in sync. Run from any directory.

set -e

MNEMOSPARK_DIR="/Users/woodrowbrown/Projects/mnemospark"
MNEMOSPARK_BACKEND_DIR="/Users/woodrowbrown/Projects/mnemospark-backend"
COMMIT_MSG="chore: update .company to latest mnemospark-docs"

update_and_push() {
  local repo_dir="$1"
  local repo_name="$2"
  echo "Updating .company submodule in $repo_name..."
  cd "$repo_dir"
  git submodule update --remote .company
  if git diff --quiet -- .company; then
    echo "  No change to .company in $repo_name; skip commit."
  else
    git add .company
    git commit -m "$COMMIT_MSG"
    git push
    echo "  Committed and pushed new .company reference in $repo_name."
  fi
}

update_and_push "$MNEMOSPARK_DIR" "mnemospark"
update_and_push "$MNEMOSPARK_BACKEND_DIR" "mnemospark-backend"

echo "Done."
