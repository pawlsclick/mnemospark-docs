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

Lists **merged** PRs in the given repo and prints only those that have comments from Cursor Bugbot (author or "Fix in Cursor" / "Fix in Web" / "@cursor push" in the body). Use this to find merged PRs that may still have suggested fixes to apply to `main`.

**Requires:** `gh` (GitHub CLI), `jq`, and `gh auth login`.

```bash
REPO=pawlsclick/mnemospark-backend ./scripts/list-merged-pr-bugbot-candidates.sh
```

See [fix/bugbot-merged-pr-fixes-workflow.md](../fix/bugbot-merged-pr-fixes-workflow.md) for the full workflow.

## review-all-bugbot-fixes.sh

For a repo, lists merged PRs that have **@cursor push** in Bugbot comments, then for each checks whether the fix commit is already in `origin/main`. Prints a table: PR, fix hash, In Main? (YES/NO), and a short diff summary for those not in main.

**Requires:** `gh`, `jq`, and (optional) `LOCAL_REPO_DIR` pointing to a local clone.

```bash
export REPO=pawlsclick/mnemospark-backend
export LOCAL_REPO_DIR=/path/to/mnemospark-backend  # optional
./scripts/review-all-bugbot-fixes.sh
```

## review-bugbot-fix.sh

For **one** PR: extracts the Bugbot `@cursor push <hash>` from comments, then in a local or cached clone checks if that commit is in `origin/main`. If not, shows `git log` and `git diff --stat` and optionally writes a full diff file.

**Requires:** `gh`, `jq`. Optional: `LOCAL_REPO_DIR` (your existing clone; otherwise uses a cache under `~/.mnemospark-bugbot/<repo-slug>`).

```bash
REPO=pawlsclick/mnemospark-backend PR=15 LOCAL_REPO_DIR=/path/to/repo ./scripts/review-bugbot-fix.sh
```

Use after the batch report to inspect a specific PR before applying the fix (e.g. via `git cherry-pick`). See [fix/bugbot-merged-pr-fixes-workflow.md](../fix/bugbot-merged-pr-fixes-workflow.md) for the full workflow.
