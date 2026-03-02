# Bugbot fix review and merge – quick start

Use Cursor Bugbot’s **@cursor push &lt;hash&gt;** comments on merged PRs to find suggested fixes, compare them to `main`, and merge only the ones that are still missing.

**Goal:** Triage which Bugbot autofixes are already in `main` vs not, then apply only the missing ones (e.g. via cherry-pick or GitHub “Create PR”).

**Prerequisites:** `gh` (GitHub CLI), `jq`, and `gh auth login`. Optional: a local clone of the target repo; set `LOCAL_REPO_DIR` to its path. The scripts only run read-only git commands until you run `git cherry-pick` or `git merge` yourself.

---

## Commands (run from mnemospark-docs)

**1. Set repo and optional local clone**

```bash
export REPO=pawlsclick/mnemospark-backend
export LOCAL_REPO_DIR=/Users/woodrowbrown/Projects/mnemospark-backend   # optional; use your existing clone
```

**2. List merged PRs with Bugbot activity**

```bash
./scripts/list-merged-pr-bugbot-candidates.sh
```

Look for **(has @cursor push — apply fix from PR comment)**.

**3. Batch report: which fixes are in main, which are not**

```bash
./scripts/review-all-bugbot-fixes.sh
```

Table shows PR, fix hash, In Main? (YES/NO), and a short summary for those NOT in main.

**4. Deep-dive one PR (full diff)**

```bash
./scripts/review-bugbot-fix.sh REPO=$REPO PR=15 LOCAL_REPO_DIR=$LOCAL_REPO_DIR
```

**5. Apply the fix (in the target repo)**

```bash
cd $LOCAL_REPO_DIR
git checkout main && git pull origin main
git cherry-pick <full-hash-from-script>
# resolve conflicts if any, run tests
git push origin main
```

Or use the **Create PR** link in the Bugbot comment and merge on GitHub.

---

## Scripts

| Script | Purpose |
|--------|--------|
| `scripts/list-merged-pr-bugbot-candidates.sh` | List merged PRs with Bugbot comments; flags “has @cursor push”. |
| `scripts/review-all-bugbot-fixes.sh` | Table of all @cursor push PRs: in main or not. |
| `scripts/review-bugbot-fix.sh` | Single PR: compare fix to main, show diff. |

**LOCAL_REPO_DIR:** Optional. If set, scripts use that directory for `git fetch` / `git log` / `git diff`. If unset, they use a cache clone under `~/.mnemospark-bugbot/<repo-slug>`. Using your existing working clone is recommended; the scripts do not modify your working tree.

---

## Full workflow

See **[bugbot-merged-pr-fixes-workflow.md](bugbot-merged-pr-fixes-workflow.md)** in this directory for the full step-by-step workflow (discovery → review → apply → repeat) and manual options.
