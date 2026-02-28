# Scripts

## update-company-submodules.sh

Updates the `.company` submodule (this repo) to the latest remote in **mnemospark** and **mnemospark-backend**, then **commits and pushes** the new submodule reference in each repo so they stay in sync and GitHub / fresh clones see the latest mnemospark-docs (including e.g. `cursor-dev-19-*` and `cursor-dev-20-*`).

```bash
./scripts/update-company-submodules.sh
```

The script:

1. In **mnemospark**: `git submodule update --remote .company`; if the submodule pointer changed, commits and pushes.
2. In **mnemospark-backend**: same.

If there is no change to `.company` in a repo (already at latest), it skips commit/push for that repo. Requires push access to both repos.

## list-merged-pr-bugbot-candidates.sh

Lists **merged** PRs in `pawlsclick/mnemospark` and prints only those that have comments that look like Cursor Bugbot (author name or "Fix in Cursor" / "Fix in Web" in the comment body). Use this to quickly find merged PRs that may still have suggested fixes to apply to `main`.

**Requires:** `gh` (GitHub CLI), `jq`, and `gh auth login`.

```bash
./scripts/list-merged-pr-bugbot-candidates.sh
```

See [features_cursor_dev/bugbot-merged-pr-fixes-workflow.md](../features_cursor_dev/bugbot-merged-pr-fixes-workflow.md) for the full workflow (manual steps + when to use this script).
