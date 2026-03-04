# Scripts

## update-company-submodules.sh

Legacy helper script for the old `.company` Git submodules. mnemospark and mnemospark-backend no longer embed this repo as a submodule; instead, contributors work directly in **mnemospark-docs**.

The script is now a **no-op** and exists only to document the previous workflow. To work with docs, simply clone or pull this repo:

```bash
git clone git@github.com:pawlsclick/mnemospark-docs.git
cd mnemospark-docs
git pull
```

## Product docs

High-level product, workflow, and API specifications live under `product_docs/` in this repo:

- [mnemospark_product_spec_v3.md](../product_docs/mnemospark_product_spec_v3.md)
- [mnemospark_PRD.md](../product_docs/mnemospark_PRD.md)
- [mnemospark_full_workflow.md](../product_docs/mnemospark_full_workflow.md)
- [mnemospark_backend_api_spec.md](../product_docs/mnemospark_backend_api_spec.md)
- [auth_no_api_key_wallet_proof_spec.md](../product_docs/auth_no_api_key_wallet_proof_spec.md)
- [wallet_gen_payment_eip712.md](../product_docs/wallet_gen_payment_eip712.md)
- [install_guidelines.md](../product_docs/install_guidelines.md)

Use these docs as the canonical reference when writing or reviewing scripts, fixing Bugbot suggestions, or coordinating feature work across repos.

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
