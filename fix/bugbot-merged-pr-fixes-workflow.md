# Workflow: Review Cursor Bugbot Fixes on Merged PRs

When branches are merged to `main`, Cursor Bugbot may have left review comments (with "Fix in Cursor" / "Fix in Web" or **@cursor push &lt;hash&gt;**). This doc describes how to find those comments, compare suggested fixes to `main`, and apply them when needed.

**Repos:** The scripts work for any GitHub repo (e.g. `pawlsclick/mnemospark`, `pawlsclick/mnemospark-backend`). Set the `REPO` environment variable.

**Local clone (`LOCAL_REPO_DIR`):** Optional but recommended. Use your existing working clone (e.g. `/Users/woodrowbrown/Projects/mnemospark-backend`). The review scripts only run read-only git commands (`fetch`, `log`, `diff`); they do not change your working tree. You only change code when you explicitly run `git cherry-pick` or `git merge` to apply a fix.

---

## Scripts overview

| Script | Purpose |
|--------|--------|
| [../scripts/list-merged-pr-bugbot-candidates.sh](../scripts/list-merged-pr-bugbot-candidates.sh) | List merged PRs that have Bugbot activity; flags PRs with **"has @cursor push"**. |
| [../scripts/review-all-bugbot-fixes.sh](../scripts/review-all-bugbot-fixes.sh) | For all PRs with `@cursor push`, check if the fix commit is in `origin/main`; print a table (IN MAIN / NOT IN MAIN). |
| [../scripts/review-bugbot-fix.sh](../scripts/review-bugbot-fix.sh) | For one PR: extract fix hash, compare to `main`, show diff if not in main. |

**Prerequisites:** `gh` (GitHub CLI), `jq`, and `gh auth login`. Optional: `LOCAL_REPO_DIR` set to your local clone so the scripts use it instead of a cache clone under `~/.mnemospark-bugbot/`.

---

## Step-by-step workflow (discovery → review → merge)

### A. Discover Bugbot autofix PRs for a repo

1. **Set the target repo and (optional) local clone path.** Example for mnemospark-backend:

   ```bash
   export REPO=pawlsclick/mnemospark-backend
   export LOCAL_REPO_DIR=/Users/woodrowbrown/Projects/mnemospark-backend
   ```

2. **List merged PRs with Bugbot activity.** From the **mnemospark-docs** repo:

   ```bash
   cd /path/to/mnemospark-docs
   ./scripts/list-merged-pr-bugbot-candidates.sh
   ```

   Look for lines that include **(has @cursor push — apply fix from PR comment)**. Those PRs have a Bugbot autofix commit you can apply.

3. **Generate a batch report of all Bugbot autofixes.** Still from mnemospark-docs:

   ```bash
   ./scripts/review-all-bugbot-fixes.sh
   ```

   This checks each `@cursor push` PR: extracts the fix commit, checks if it’s in `origin/main`, and prints a table. PRs marked **NO** under "In Main?" have fixes not yet in `main`.

### B. Deep-dive review for a specific fix

4. **Pick one PR the batch report marks as NOT in main** (e.g. PR #15).

5. **Run the single-fix review script for that PR:**

   ```bash
   ./scripts/review-bugbot-fix.sh REPO=$REPO PR=15 LOCAL_REPO_DIR=$LOCAL_REPO_DIR
   ```

   The script prints whether the fix is in `origin/main`, and if not, a `git log` and `git diff --stat` summary. It may also write a full diff to `bugbot-fix-<PR>-<hash>.diff` in the current directory.

### C. Apply the fix into main (if you approve it)

6. **Sync your local `main`** in the target repo:

   ```bash
   cd $LOCAL_REPO_DIR
   git checkout main
   git pull origin main
   ```

7. **Apply the Bugbot fix** (choose one):

   - **Option 1 – Cherry-pick (recommended when the fix is one commit):**

     ```bash
     git cherry-pick <full-hash-from-review-script>
     ```

     Resolve conflicts if any, then run tests.

   - **Option 2 – Merge the Bugbot branch** (if you see the branch name in the Bugbot "Create PR" link, e.g. `cursor/housekeeping-scan-limit-140b`):

     ```bash
     git fetch origin cursor/housekeeping-scan-limit-140b
     git merge origin/cursor/housekeeping-scan-limit-140b
     ```

   - **Option 3 – GitHub UI:** Click **Create PR** in the Bugbot comment, review and merge into `main` on GitHub, then `git pull origin main` locally.

8. **Push to GitHub** (if you applied locally):

   ```bash
   git push origin main
   ```

9. **Optional:** Note on the original Bugbot PR that the fix was applied to `main`; close redundant PRs if needed.

### D. Repeat for other missing fixes

10. Use the batch report again to find remaining PRs marked NOT in main. For each, run `review-bugbot-fix.sh` for that PR number, then apply via cherry-pick, merge, or GitHub "Create PR" as above.

---

## Manual discovery (without scripts)

### Find merged PRs on GitHub

1. Open the repo on GitHub (e.g. **https://github.com/pawlsclick/mnemospark** or **pawlsclick/mnemospark-backend**).
2. Go to **Pull requests**, filter **Closed** / **Merged**, sort by **Updated** or **Closed**.

### Find Bugbot comments on a PR

- Open each merged PR; check **Conversation** and **Files changed**.
- Look for comments from **cursor bot** / **Cursor Bugbot**.
- Bugbot comments often include:
  - **"Cursor Bugbot has reviewed your changes and found N potential issue(s)"** and **"✔ Fixed: …"**.
  - **Bugbot Autofix:** **Create PR** button and/or **"Or push these changes by commenting: `@cursor push <commit-hash>`"** (e.g. `@cursor push 0509bc8a89`).
  - A follow-up with **Severity** and **Fix in Cursor** / **Fix in Web** buttons.

### One-off gh commands

```bash
# List merged PRs (set REPO or replace org/repo)
gh pr list --repo pawlsclick/mnemospark-backend --state merged --limit 50

# List comments on a specific PR (replace 123 with PR number)
gh api repos/pawlsclick/mnemospark-backend/issues/123/comments
gh api repos/pawlsclick/mnemospark-backend/pulls/123/comments
```

Filter or grep the JSON for the bot’s `user.login` or for `"Fix in Cursor"` / `"Fix in Web"` / `"@cursor push"` in the body.

---

## References

- [Cursor Bugbot docs](https://cursor.com/docs/bugbot) – how Bugbot works, "Fix in Cursor" / "Fix in Web", autofix options.
- Quick start: [README.md in this directory](README.md) – runnable steps and commands.
