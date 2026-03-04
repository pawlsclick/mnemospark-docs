# Cursor Dev: Docs and tests — mnemospark command structure (wallet, cloud, MNEMOSPARK_WALLET_KEY)

**ID:** cursor-dev-27  
**Repo:** mnemospark-docs

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-docs (documentation and test scripts). Do **not** open, clone, or require access to mnemospark or mnemospark-backend; all content is in this repo. The spec for this feature is at `features_cursor_dev/cursor-dev-27-docs-wallet-command-and-env.md`.

**AWS:** When implementing or changing AWS services or resources, follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available when working on AWS-based services.

## Scope

Depends on cursor-dev-26 (mnemospark code changes merged).

Update all documentation and test scripts in mnemospark-docs to use the new mnemospark command structure: `/mnemospark wallet`, `/mnemospark cloud` (and subcommands), and `MNEMOSPARK_WALLET_KEY`.

1. **mnemospark_full_workflow.md — Client command behavior**
   - Update the **"mnemospark-client commands"** section (and any table or list of slash commands) so the supported commands are:
     - `/mnemospark cloud` (replacing `/cloud`)
     - `/mnemospark cloud help` (replacing `/cloud help`)
     - `/mnemospark cloud backup` (replacing `/cloud backup`)
     - `/mnemospark cloud price-storage` (replacing `/cloud price-storage`)
     - `/mnemospark cloud upload` (replacing `/cloud upload`)
     - `/mnemospark cloud ls` (replacing `/cloud ls`)
     - `/mnemospark cloud download` (replacing `/cloud download`)
     - `/mnemospark cloud delete` (replacing `/cloud delete`)
     - `/mnemospark wallet` (replacing `/wallet`)
   - Replace every remaining occurrence of `/cloud` or `/wallet` in the workflow doc (section headings, examples, "run /cloud ..." instructions) with `/mnemospark cloud` or `/mnemospark wallet` as appropriate. Preserve the meaning of each section (e.g. "cloud command", "help command", "backup command") but use the new command names in headings and body text.

2. **Wallet command and env in other docs**
   - Search the repo for `/wallet` and wallet command references that describe mnemospark. Replace with `/mnemospark wallet` and `/mnemospark wallet export` as appropriate.
   - Replace references to `BLOCKRUN_WALLET_KEY` with `MNEMOSPARK_WALLET_KEY` in installation guide, workflow doc, and any other docs. Ensure docs state that mnemospark uses `MNEMOSPARK_WALLET_KEY` and `/mnemospark wallet`; `/wallet` is used by ClawRouter/Blockrun.
   - Files to check: [ops/mnemospark_installation_guide.md](ops/mnemospark_installation_guide.md), [mnemospark_full_workflow.md](../product_docs/mnemospark_full_workflow.md), any other markdown under ops/, features_cursor_dev/, or root.

3. **Cloud command references**
   - Search the repo for `/cloud` in docs (help examples, "run /cloud upload", etc.). Replace with `/mnemospark cloud` (and subcommands) so all user-facing command examples are consistent with cursor-dev-26.

4. **Test scripts**
   - In [tests/](tests/): update any script or comment that refers to `/wallet`, `/cloud`, or `BLOCKRUN_WALLET_KEY` in the context of mnemospark to `/mnemospark wallet`, `/mnemospark cloud`, and `MNEMOSPARK_WALLET_KEY`. Update assertions if they check command output or env names.

5. **Consistency**
   - Ensure no doc in this repo tells users to run `/wallet` or `/cloud` for mnemospark or to set `BLOCKRUN_WALLET_KEY` for mnemospark; use `/mnemospark wallet`, `/mnemospark cloud` (and subcommands), and `MNEMOSPARK_WALLET_KEY` throughout.

## References

- [ops/mnemospark_installation_guide.md](ops/mnemospark_installation_guide.md)
- [mnemospark_full_workflow.md](../product_docs/mnemospark_full_workflow.md)
- [tests/](tests/)
- Plan: [.cursor/plans/wallet-command-mnemospark-wallet-migration.plan.md](.cursor/plans/wallet-command-mnemospark-wallet-migration.plan.md)

## Cloud Agent

- **Install (idempotent):** None (markdown and shell scripts).
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] mnemospark_full_workflow.md "mnemospark-client commands" section lists `/mnemospark cloud`, `/mnemospark cloud help`, backup, price-storage, upload, ls, download, delete, and `/mnemospark wallet` (no bare `/cloud` or `/wallet`).
  - [ ] All other occurrences of `/cloud` and `/wallet` in the workflow doc (headings, examples, instructions) updated to `/mnemospark cloud` and `/mnemospark wallet`.
  - [ ] All mnemospark wallet env references in docs use `MNEMOSPARK_WALLET_KEY` (no `BLOCKRUN_WALLET_KEY` for mnemospark).
  - [ ] Installation guide and any other docs updated for wallet, cloud, and env naming.
  - [ ] Test scripts in tests/ updated to use `/mnemospark wallet`, `/mnemospark cloud`, and `MNEMOSPARK_WALLET_KEY` when describing or testing mnemospark.
  - [ ] Docs and tests are consistent with cursor-dev-26 behavior.

## Task string (optional)

Work only in mnemospark-docs. Update all docs and test scripts for the mnemospark command structure: (1) mnemospark_full_workflow.md — update "mnemospark-client commands" to list /mnemospark cloud, /mnemospark cloud help, backup, price-storage, upload, ls, download, delete, and /mnemospark wallet; replace every /cloud and /wallet in the doc with /mnemospark cloud and /mnemospark wallet. (2) Replace BLOCKRUN_WALLET_KEY with MNEMOSPARK_WALLET_KEY everywhere. (3) Update ops/mnemospark_installation_guide.md and any other docs. (4) Update tests/ scripts and assertions. Acceptance: [ ] workflow doc command list and all /cloud,/wallet refs updated; [ ] MNEMOSPARK_WALLET_KEY; [ ] installation guide and tests; [ ] consistent with cursor-dev-26.
