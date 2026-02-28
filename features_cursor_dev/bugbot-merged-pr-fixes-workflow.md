# Workflow: Review Cursor Bugbot Fixes on Merged PRs

When branches are merged to `main`, Cursor Bug BOT may have already left review comments (with "Fix in Cursor" / "Fix in Web" or suggested commits). This doc describes how to find those comments and decide whether to apply fixes to `main`.

## 1. Find merged PRs (manual)

1. Open the repo on GitHub: **https://github.com/pawlsclick/mnemospark**
2. Go to **Pull requests**.
3. Set filters:
   - **Status**: Closed
   - In the search box use: `is:merged` (or use the "Merged" filter if available).
4. Sort by **Updated** or **Closed** to work through recent merges.

## 2. Find Bugbot comments on a PR

- Open each merged PR.
- Scroll through **Conversation** and **Files changed**.
- Look for comments from **cursor bot** (or **Cursor Bugbot** / the Cursor GitHub App name you have installed).
- Bugbot comments often include:
  - **"Cursor Bugbot has reviewed your changes and found N potential issue(s)"** with a short fix summary (e.g. **"✔ Fixed: …"**).
  - **Bugbot Autofix**: a **Create PR** button and/or the line **"Or push these changes by commenting: `@cursor push <commit-hash>`"** (e.g. `@cursor push 0509bc8a89`). A **Preview** link shows the diff for that commit.
  - A follow-up comment with **Severity** (e.g. Medium Severity), more detail, and **Fix in Cursor** / **Fix in Web** buttons.
  - **Fix in Cursor** – opens the fix flow in Cursor IDE.
  - **Fix in Web** – opens in [cursor.com/agents](https://cursor.com/agents).

## 3. Decide and apply fixes

For each Bugbot comment you care about:

1. **Review the suggestion** – read the severity and description; decide if it’s a real bug/improvement or a false positive.
2. **Apply the fix** (choose one):
   - **Option A (from GitHub):** If the comment shows **Create PR**, click it to open a new PR with the autofix. Merge that PR into `main`.  
     Or comment on the PR: **`@cursor push <commit-hash>`** (use the hash from the comment, e.g. `0509bc8a89`). That pushes the fix to the branch; then create/merge a PR to `main`.
   - **Option B:** Use **Fix in Cursor** from the PR comment (or open the PR in Cursor and use the comment there). Apply the fix in your local branch, then commit and push to `main` (or a fix branch you merge to `main`).
   - **Option C:** Manually apply the same change on `main` (or a fix branch), commit, and push.
3. **Optional:** Reply on the PR that the fix was applied on `main` so the thread is closed.

## 4. Automate discovery (optional): script

Use the helper script to list **merged** PRs and their comment count (and optionally bodies), so you can quickly see which PRs likely have Bugbot feedback:

```bash
# From mnemospark-docs repo
./scripts/list-merged-pr-bugbot-candidates.sh
```

Requires [GitHub CLI](https://cli.github.com/) (`gh`) and `jq` installed, and `gh auth login`. The script:

- Lists merged PRs for `pawlsclick/mnemospark`.
- For each, fetches issue comments (PR-level) and review comments (inline).
- Highlights PRs that have comments from a Cursor/Bugbot-related author (e.g. `cursor-bugbot`, `cursor[bot]`) or that contain "Fix in Cursor" / "Fix in Web".

Then open the reported PRs on GitHub and follow **§2** and **§3** above.

## 5. One-off `gh` commands (no script)

If you prefer not to use the script:

```bash
# List merged PRs (mnemospark repo)
gh pr list --repo pawlsclick/mnemospark --state merged --limit 50

# List comments on a specific PR (replace 123 with PR number)
gh api repos/pawlsclick/mnemospark/issues/123/comments
gh api repos/pawlsclick/mnemospark/pulls/123/comments
```

Filter or grep the JSON for the Bot’s `user.login` or for `"Fix in Cursor"` / `"Fix in Web"` in the body.

## References

- [Cursor Bugbot docs](https://cursor.com/docs/bugbot) – how Bugbot works, "Fix in Cursor" / "Fix in Web", autofix options.
- Repo: `git@github.com:pawlsclick/mnemospark.git`
