#!/usr/bin/env bash
# For a repo, list merged PRs that have "@cursor push" in Bugbot comments, then for each
# run the single-fix review and print a table: PR, fix hash, in main?, summary.
# Requires: gh, jq. Usage: REPO=org/repo [LOCAL_REPO_DIR=/path] [LIMIT=50] ./scripts/review-all-bugbot-fixes.sh

set -e

REPO="${REPO:?Set REPO (e.g. pawlsclick/mnemospark-backend)}"
LOCAL_REPO_DIR="${LOCAL_REPO_DIR:-}"
LIMIT="${LIMIT:-50}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get merged PRs
PRS=$(gh pr list --repo "$REPO" --state merged --limit "$LIMIT" --json number,title,mergedAt)
COUNT=$(echo "$PRS" | jq -r 'length')

# Collect PR numbers that have "@cursor push" in issue or review comments
push_prs=()
for i in $(seq 0 $((COUNT - 1))); do
  num=$(echo "$PRS" | jq -r ".[$i].number")
  issue_comments=$(gh api "repos/$REPO/issues/$num/comments" 2>/dev/null || echo "[]")
  review_comments=$(gh api "repos/$REPO/pulls/$num/comments" 2>/dev/null || echo "[]")
  if echo "$issue_comments" | jq -e "[.[].body // \"\" | test(\"@cursor push\"; \"i\")] | any" >/dev/null 2>&1; then
    push_prs+=( "$num" )
  elif echo "$review_comments" | jq -e "[.[].body // \"\" | test(\"@cursor push\"; \"i\")] | any" >/dev/null 2>&1; then
    push_prs+=( "$num" )
  fi
done

if [[ ${#push_prs[@]} -eq 0 ]]; then
  echo "No merged PRs with '@cursor push' in $REPO (limit $LIMIT)."
  exit 0
fi

echo "REPO=$REPO"
[[ -n "$LOCAL_REPO_DIR" ]] && echo "LOCAL_REPO_DIR=$LOCAL_REPO_DIR" || echo "LOCAL_REPO_DIR=(cache: ~/.mnemospark-bugbot/${REPO##*/})"
echo ""
printf "%-6s %-12s %-8s %s\n" "PR" "Fix Hash" "In Main?" "Summary"
echo "----------------------------------------------------------------------"

for pr in "${push_prs[@]}"; do
  PR="$pr"
  export REPO PR LOCAL_REPO_DIR
  line=$("$SCRIPT_DIR/review-bugbot-fix.sh" 2>/dev/null | head -1)
  if [[ -z "$line" ]]; then
    printf "%-6s %-12s %-8s %s\n" "$pr" "—" "?" "(error or no hash)"
    continue
  fi
  if [[ "$line" =~ already\ in\ origin/main ]]; then
    hash=$(echo "$line" | grep -oE 'fix [0-9a-f]+' | sed 's/fix //')
    printf "%-6s %-12s %-8s %s\n" "$pr" "$hash" "YES" "(already merged)"
  else
    hash=$(echo "$line" | grep -oE 'fix [0-9a-f]+' | sed 's/fix //')
    summary=$(echo "$line" | sed -n 's#.*NOT in origin/main (\(.*\)).*#\1#p')
    printf "%-6s %-12s %-8s %s\n" "$pr" "$hash" "NO" "${summary:-—}"
  fi
done

echo ""
echo "Run: ./scripts/review-bugbot-fix.sh REPO=$REPO PR=<num> LOCAL_REPO_DIR=\$LOCAL_REPO_DIR for full diff."
