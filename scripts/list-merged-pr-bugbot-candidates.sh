#!/usr/bin/env bash
# List merged PRs in pawlsclick/mnemospark and flag which have comments from
# Cursor Bugbot (author "cursor bot" / cursor-bot, or body: "Fix in Cursor",
# "Bugbot Autofix", "@cursor push", severity, etc.).
# Requires: gh CLI (https://cli.github.com/), jq, and `gh auth login`.

set -e

REPO="${REPO:-pawlsclick/mnemospark-backend}"
LIMIT="${LIMIT:-50}"

# Match Bugbot comment bodies (multiline-safe via jq). Patterns from GitHub UI:
# - "Cursor Bugbot has reviewed your changes and found N potential issue"
# - "Bugbot Autofix prepared a fix" / "Create PR" / "Or push these changes by commenting: @cursor push <hash>"
# - "Fix in Cursor" / "Fix in Web"
# - "✔ Fixed:" / "Medium Severity" etc.
BUGBOT_BODY_PATTERN='Fix in (Cursor|Web)|cursor review|bugbot|Cursor Bugbot|Bugbot Autofix|@cursor push|✔ Fixed:|(High|Medium|Low) Severity'

echo "Fetching merged PRs in $REPO (limit $LIMIT)..."
echo ""

PRS=$(gh pr list --repo "$REPO" --state merged --limit "$LIMIT" --json number,title,mergedAt,url)
COUNT=$(echo "$PRS" | jq -r 'length')

for i in $(seq 0 $((COUNT - 1))); do
  num=$(echo "$PRS" | jq -r ".[$i].number")
  title=$(echo "$PRS" | jq -r ".[$i].title")
  merged=$(echo "$PRS" | jq -r ".[$i].mergedAt")
  url=$(echo "$PRS" | jq -r ".[$i].url")

  # Issue comments (PR-level) and review comments (inline)
  issue_comments=$(gh api "repos/$REPO/issues/$num/comments" 2>/dev/null || echo "[]")
  review_comments=$(gh api "repos/$REPO/pulls/$num/comments" 2>/dev/null || echo "[]")

  has_bugbot=false
  bugbot_reasons=""
  has_autofix_push=""

  # Check issue comment bodies (jq handles full body including newlines)
  if echo "$issue_comments" | jq -e "[.[].body // \"\" | test(\"$BUGBOT_BODY_PATTERN\"; \"i\")] | any" >/dev/null 2>&1; then
    has_bugbot=true
    bugbot_reasons="${bugbot_reasons} [issue: Bugbot body]"
  fi
  if echo "$issue_comments" | jq -e "[.[].body // \"\" | test(\"@cursor push\"; \"i\")] | any" >/dev/null 2>&1; then
    has_autofix_push=" (has @cursor push — apply fix from PR comment)"
  fi
  for login in $(echo "$issue_comments" | jq -r '.[].user.login // empty'); do
    if echo "$login" | grep -qi "cursor\|bugbot"; then
      has_bugbot=true
      bugbot_reasons="${bugbot_reasons} [issue by: $login]"
    fi
  done

  # Check review comment bodies and authors
  if echo "$review_comments" | jq -e "[.[].body // \"\" | test(\"$BUGBOT_BODY_PATTERN\"; \"i\")] | any" >/dev/null 2>&1; then
    has_bugbot=true
    bugbot_reasons="${bugbot_reasons} [review: Bugbot body]"
  fi
  if echo "$review_comments" | jq -e "[.[].body // \"\" | test(\"@cursor push\"; \"i\")] | any" >/dev/null 2>&1; then
    has_autofix_push=" (has @cursor push — apply fix from PR comment)"
  fi
  for login in $(echo "$review_comments" | jq -r '.[].user.login // empty'); do
    if echo "$login" | grep -qi "cursor\|bugbot"; then
      has_bugbot=true
      bugbot_reasons="${bugbot_reasons} [review by: $login]"
    fi
  done

  if [ "$has_bugbot" = true ]; then
    echo "► #$num (merged $merged) $bugbot_reasons$has_autofix_push"
    echo "  $title"
    echo "  $url"
    echo ""
  fi
done

echo "Done. Open the URLs above. To apply an autofix: use 'Create PR' on the comment or comment @cursor push <commit-hash> on the PR, then merge to main."
