#!/usr/bin/env bash
# For one PR, extract the Bugbot "@cursor push <hash>" from comments, then in a
# local or cached clone check if that commit is in origin/main and show diff if not.
# Requires: gh, jq, and (for clone fallback) gh auth.
# Usage: REPO=org/repo PR=123 [LOCAL_REPO_DIR=/path] ./scripts/review-bugbot-fix.sh

set -e

REPO="${REPO:?Set REPO (e.g. pawlsclick/mnemospark-backend)}"
PR="${PR:?Set PR (e.g. 15)}"
LOCAL_REPO_DIR="${LOCAL_REPO_DIR:-}"

# Extract first @cursor push <hash> from comment bodies (short hash, e.g. 8a2d1da92c)
extract_push_hash() {
  local comments="$1"
  echo "$comments" | jq -r '.[].body // ""' | grep -oE '@cursor push ([0-9a-f]+)' | head -1 | sed 's/@cursor push //'
}

# Resolve short hash to full 40-char hash in repo dir; exit 1 if not found
resolve_hash() {
  local repo_dir="$1"
  local short_hash="$2"
  (cd "$repo_dir" && git rev-parse "$short_hash" 2>/dev/null) || return 1
}

# Determine repo directory: use LOCAL_REPO_DIR or clone under ~/.mnemospark-bugbot/<slug>
slug="${REPO##*/}"
CACHE_DIR="$HOME/.mnemospark-bugbot/$slug"

if [[ -n "$LOCAL_REPO_DIR" ]]; then
  if [[ ! -d "$LOCAL_REPO_DIR/.git" ]]; then
    echo "Error: LOCAL_REPO_DIR is set but not a git repo: $LOCAL_REPO_DIR" >&2
    exit 1
  fi
  REPO_DIR="$LOCAL_REPO_DIR"
else
  if [[ ! -d "$CACHE_DIR/.git" ]]; then
    echo "Cloning $REPO into $CACHE_DIR (cache)..." >&2
    mkdir -p "$(dirname "$CACHE_DIR")"
    gh repo clone "$REPO" "$CACHE_DIR"
  fi
  REPO_DIR="$CACHE_DIR"
fi

# Fetch comments
issue_comments=$(gh api "repos/$REPO/issues/$PR/comments" 2>/dev/null || echo "[]")
review_comments=$(gh api "repos/$REPO/pulls/$PR/comments" 2>/dev/null || echo "[]")

# Try issue comments first, then review comments
short_hash=$(extract_push_hash "$issue_comments")
if [[ -z "$short_hash" ]]; then
  short_hash=$(extract_push_hash "$review_comments")
fi

if [[ -z "$short_hash" ]]; then
  echo "PR #$PR: no '@cursor push <hash>' found in comments." >&2
  exit 1
fi

# Update repo and resolve hash
(cd "$REPO_DIR" && git fetch origin --quiet 2>/dev/null) || true
full_hash=$(resolve_hash "$REPO_DIR" "$short_hash") || {
  echo "PR #$PR: fix commit $short_hash not found in repo (branch may be deleted)." >&2
  exit 1
}

# Check if already in main
if (cd "$REPO_DIR" && git merge-base --is-ancestor "$full_hash" origin/main 2>/dev/null); then
  echo "PR #$PR: fix $short_hash — already in origin/main."
  exit 0
fi

# Not in main: show log and diff stat
diff_stat=$(cd "$REPO_DIR" && git diff --stat --no-color origin/main.."$full_hash" 2>/dev/null | tail -1)
echo "PR #$PR: fix $short_hash — NOT in origin/main ($diff_stat)"
echo ""
echo "Commits:"
(cd "$REPO_DIR" && git log --oneline origin/main.."$full_hash" 2>/dev/null)
echo ""
echo "Diff stat:"
(cd "$REPO_DIR" && git diff --stat --no-color origin/main.."$full_hash" 2>/dev/null)

# Optional: write full diff to a file in cwd (mnemospark-docs when run from there)
DIFF_FILE="bugbot-fix-${PR}-${short_hash}.diff"
if [[ -w . ]]; then
  (cd "$REPO_DIR" && git diff --no-color origin/main.."$full_hash" 2>/dev/null) > "$DIFF_FILE" 2>/dev/null && echo "" && echo "Full diff written to: $DIFF_FILE"
fi
