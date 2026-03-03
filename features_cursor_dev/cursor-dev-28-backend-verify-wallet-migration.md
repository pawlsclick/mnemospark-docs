# Cursor Dev: Backend — verify mnemospark command-structure migration does not break APIs

**ID:** cursor-dev-28  
**Repo:** mnemospark-backend

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend (Lambda, API Gateway, wallet-proof authorizer). Do **not** open, clone, or require access to mnemospark or mnemospark-docs; all code and references are in this repo and `.company/`. The spec for this feature is in mnemospark-docs at `features_cursor_dev/cursor-dev-28-backend-verify-wallet-migration.md`.

**AWS:** When implementing or changing AWS services or resources, follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available when working on AWS-based services.

## Scope

Depends on cursor-dev-26 (mnemospark client uses `/mnemospark wallet`, `/mnemospark cloud`, and `MNEMOSPARK_WALLET_KEY`). The backend does **not** receive chat command names or the env var name; it only validates wallet-proof signatures and `wallet_address` in requests. This task is verification and doc cleanup only.

1. **Command names and API calls**
   - Confirm that no backend API or Lambda is invoked by “command name”; the client sends signed requests with `wallet_address` (and possibly headers like `x-wallet-signature`). The change from `/wallet` and `/cloud` to `/mnemospark wallet` and `/mnemospark cloud` is client-only. No backend API contract change is required.
   - If any backend doc or comment mentions “/wallet” as the trigger for an API call, update it to “/mnemospark wallet” or “mnemospark wallet command” for clarity.

2. **Wallet and cloud references in docs/tests**
   - In list item 1, ensure backend docs that mention the trigger for API calls reference `/mnemospark wallet` or `/mnemospark cloud` (not bare `/wallet` or `/cloud`).
   - Search for references to `BLOCKRUN_WALLET_KEY`, `/wallet`, or `/cloud` in this repo's tests or scripts. If any refer to the mnemospark client (e.g. instructions to set env for proxy, or user runs /cloud upload), update to `MNEMOSPARK_WALLET_KEY`, `/mnemospark wallet`, and `/mnemospark cloud` for consistency; if they refer to a different product (e.g. Blockrun), leave them as-is.

3. **All testing scripts**
   - Grep for wallet-related env vars and command names in tests/ and scripts/. Update only mnemospark-specific references to the new naming.

4. **Ensure no breakage**
   - Wallet-authorizer and storage Lambdas do not depend on env var name or chat command name; they validate EIP-712 signature and wallet_address. Run existing tests (e.g. wallet-authorizer, storage) to confirm nothing is broken. If any test was explicitly asserting client-side env or command names, update assertions and re-run.

## References

- [services/wallet-authorizer/app.py](services/wallet-authorizer/app.py) — validates wallet proof; no dependency on BLOCKRUN_WALLET_KEY or /wallet
- [.company/](.company/) — any backend-facing API or workflow docs
- Plan: See mnemospark-docs repo `.cursor/plans/wallet-command-mnemospark-wallet-migration.plan.md`.

## Cloud Agent

- **Install (idempotent):** Per repo (e.g. `pip install -r requirements.txt` or project-specific).
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] No backend API or Lambda logic depends on `/wallet`, `/cloud`, or `BLOCKRUN_WALLET_KEY`; wallet proof and wallet_address are unchanged.
  - [ ] Any backend docs or comments that mentioned /wallet or /cloud for mnemospark updated to /mnemospark wallet and /mnemospark cloud; any mnemospark client env instructions updated to MNEMOSPARK_WALLET_KEY.
  - [ ] Existing wallet-authorizer and storage tests pass.
  - [ ] Test scripts in this repo that reference mnemospark client commands or env use the new names (/mnemospark wallet, /mnemospark cloud, MNEMOSPARK_WALLET_KEY).

## Task string (optional)

Work only in mnemospark-backend. Verify mnemospark command-structure migration does not break APIs: backend does not use command name or env var name; only wallet proof and wallet_address. Update any docs/tests that reference /wallet, /cloud, or BLOCKRUN_WALLET_KEY for mnemospark to /mnemospark wallet, /mnemospark cloud, and MNEMOSPARK_WALLET_KEY. Run existing tests. Acceptance: [ ] no API contract change; [ ] docs/tests updated; [ ] tests pass.
