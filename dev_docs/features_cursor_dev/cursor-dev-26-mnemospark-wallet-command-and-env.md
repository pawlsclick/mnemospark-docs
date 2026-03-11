# Cursor Dev: mnemospark command structure — /mnemospark-wallet, /mnemospark-cloud, MNEMOSPARK_WALLET_KEY

**ID:** cursor-dev-26  
**Repo:** mnemospark

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark (OpenClaw plugin). Do **not** open, clone, or require access to mnemospark-backend or other repositories. The canonical spec for this feature lives in the **mnemospark-docs** repo at `features_cursor_dev/cursor-dev-26-mnemospark-wallet-command-and-env.md`.

**AWS:** When implementing or changing AWS services or resources, follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available when working on AWS-based services.

## Scope

Implement the full mnemospark command-structure migration so mnemospark does not conflict with ClawRouter/Blockrun and all mnemospark commands live under the `/mnemospark` namespace: (1) `/mnemospark-wallet` and `/mnemospark-wallet export` replace `/wallet`; (2) `/mnemospark-cloud` and all subcommands replace `/cloud`; (3) `MNEMOSPARK_WALLET_KEY` replaces `BLOCKRUN_WALLET_KEY`; (4) wallet resolution order updated as specified.

1. **Environment variable**
   - Replace usage of `BLOCKRUN_WALLET_KEY` with `MNEMOSPARK_WALLET_KEY` everywhere in this repo (auth, CLI, cloud-command, plugin config schema, help text, error messages, and any tests that reference the env var).
   - Keep the **file path** constant `WALLET_FILE` (mnemospark wallet path) and `LEGACY_WALLET_FILE` (blockrun path) as-is; only the **env var name** changes to `MNEMOSPARK_WALLET_KEY`.

2. **Wallet command: `/mnemospark-wallet`**
   - mnemospark must **not** register a command named `wallet` that would be exposed as `/wallet` (to avoid clashing with ClawRouter).
   - Register the wallet command so the user invokes **`/mnemospark-wallet`** (and optionally `/mnemospark-wallet export`). How OpenClaw namespaces commands (e.g. by plugin id) may require registering a command with a name like `"wallet"` under plugin id `mnemospark`, resulting in `/mnemospark-wallet`; if the API requires a different pattern to achieve `/mnemospark-wallet`, follow the OpenClaw plugin SDK so the effective command is `/mnemospark-wallet`.
   - In the wallet command handler, read only the mnemospark wallet file (`WALLET_FILE` = `~/.openclaw/mnemospark/wallet/wallet.key`). If missing/invalid, return an error: "No mnemospark wallet found. Run `openclaw plugins install mnemospark` or set MNEMOSPARK_WALLET_KEY."
   - Update in-command text that refers to restore steps: use `MNEMOSPARK_WALLET_KEY` and the mnemospark wallet path in examples (e.g. `~/.openclaw/mnemospark/wallet/wallet.key`).
   - Update help/description strings that mention `/wallet` to say `/mnemospark-wallet` and `/mnemospark-wallet export`.

3. **Wallet resolution for proxy/CLI** (`resolveOrGenerateWalletKey` in `src/auth.ts`)
   - Order: (1) Load from saved files: prefer `WALLET_FILE` (mnemospark), then `LEGACY_WALLET_FILE` (blockrun) if mnemospark file missing. (2) If neither file present, **do not** use any env var; auto-generate a new wallet and write to `WALLET_FILE`.
   - Remove the current step that reads `BLOCKRUN_WALLET_KEY`. Remove or repurpose `envKeyAuth` / env-based auth for mnemospark to use `MNEMOSPARK_WALLET_KEY` only if you keep an env auth method (e.g. for wizard); otherwise remove env from resolution so resolution is file-only then auto-generate.
   - **Clarification:** For proxy and CLI startup, resolution is file-first then auto-generate. For the **cloud-command** (storage flows), use the new order in the next bullet.

4. **Cloud storage wallet resolution** (`resolveWalletPrivateKey` in `src/cloud-command.ts`)
   - Order: (1) `MNEMOSPARK_WALLET_KEY` env var (if valid hex key). (2) `~/.openclaw/mnemospark/wallet/wallet.key`. (3) `~/.openclaw/blockrun/wallet.key`.
   - If none found, throw (or return) error: "No mnemospark wallet found. Run `openclaw plugins install mnemospark` or set MNEMOSPARK_WALLET_KEY."
   - Replace any reference to `BLOCKRUN_WALLET_KEY` or "run /wallet first" in this file with the new message and `MNEMOSPARK_WALLET_KEY`.

5. **CLI** (`src/cli.ts`)
   - Help text: document `MNEMOSPARK_WALLET_KEY` instead of `BLOCKRUN_WALLET_KEY`.
   - Install success messages: when wallet is sourced from env, say `MNEMOSPARK_WALLET_KEY` and persist path `~/.openclaw/mnemospark/wallet/wallet.key`.
   - Proxy startup log: when key comes from env, log "Using wallet from MNEMOSPARK_WALLET_KEY".

6. **Plugin config and types**
   - In `openclaw.plugin.json` configSchema / uiHints, if wallet key is described, reference `MNEMOSPARK_WALLET_KEY` and `/mnemospark-wallet` where relevant.

7. **Tests**
   - Update unit/integration tests that set or assert `BLOCKRUN_WALLET_KEY` to use `MNEMOSPARK_WALLET_KEY`.
   - Update tests that invoke or assert the wallet command to use `/mnemospark-wallet` (or the registered command name that yields that).
   - Ensure `resolveOrGenerateWalletKey` and `resolveWalletPrivateKey` tests cover: mnemospark file only, blockrun file only, env only (cloud), and auto-generate when no file.

8. **Cloud command: `/mnemospark-cloud`**
   - mnemospark must **not** register a command that is exposed as `/cloud` (to avoid future conflict). Register the cloud command so the user invokes **`/mnemospark-cloud`**, **`/mnemospark-cloud help`**, **`/mnemospark-cloud backup`**, **`/mnemospark-cloud price-storage`**, **`/mnemospark-cloud upload`**, **`/mnemospark-cloud ls`**, **`/mnemospark-cloud download`**, **`/mnemospark-cloud delete`**. Follow the OpenClaw plugin SDK so the effective commands are under `/mnemospark-cloud` (e.g. plugin id + command name or nested command registration as the SDK supports).
   - In **src/cloud-command.ts**: replace every user-facing string that contains `/cloud` with `/mnemospark-cloud` — e.g. help text (`/cloud` → `/mnemospark-cloud`, `/cloud help` → `/mnemospark-cloud help`, `/cloud backup ...` → `/mnemospark-cloud backup ...`, and similarly for price-storage, upload, ls, download, delete). Update the next-step message after price-storage quote to say "run the command /mnemospark-cloud upload ...". Update error messages that say "Run /cloud price-storage first" or "Run /cloud backup first" to "Run /mnemospark-cloud price-storage first" and "Run /mnemospark-cloud backup first".
   - In **src/proxy.ts**: update comments and error messages that mention "/cloud" (e.g. "Invalid JSON body for /cloud price-storage", "Failed to forward /cloud upload") to "/mnemospark-cloud ...". Update the help string that says "run /cloud upload" to "run /mnemospark-cloud upload".
   - In **src/index.ts**: update the log message "Failed to register /cloud command" to "Failed to register /mnemospark-cloud command".
   - In **tests** (e.g. cloud-command.test.ts): update expectations and it() descriptions that reference `/cloud` to `/mnemospark-cloud` (e.g. expected help text lines, "Run /cloud ..." in messages).
   - In-repo docs (README, CHANGELOG): replace any `/cloud` examples or instructions with `/mnemospark-cloud` equivalents.

9. **Docs in repo**
   - README, CHANGELOG, or other in-repo docs: replace `/wallet` with `/mnemospark-wallet`, `/cloud` with `/mnemospark-cloud`, and `BLOCKRUN_WALLET_KEY` with `MNEMOSPARK_WALLET_KEY` where they describe mnemospark behavior.

## References

- [src/auth.ts](src/auth.ts) — `resolveOrGenerateWalletKey`, `loadSavedWallet`, `envKeyAuth`, `LEGACY_WALLET_FILE`, `WALLET_FILE`
- [src/index.ts](src/index.ts) — `createWalletCommand`, `registerCommand`, wallet handler and export text
- [src/cloud-command.ts](src/cloud-command.ts) — `resolveWalletPrivateKey`, help/error strings (wallet and cloud commands)
- [src/proxy.ts](src/proxy.ts) — error/help strings mentioning /cloud
- [src/cli.ts](src/cli.ts) — help, install messages, proxy startup
- [openclaw.plugin.json](openclaw.plugin.json) — configSchema.walletKey description
- Plan: `.cursor/plans/wallet-command-mnemospark-wallet-migration.plan.md` in this repo, or see the corresponding plan in the **mnemospark-docs** repo.

## Cloud Agent

- **Install (idempotent):** `npm install`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] mnemospark does not register `/wallet` or `/cloud`; users use `/mnemospark-wallet` (and `/mnemospark-wallet export`) and `/mnemospark-cloud` (and `/mnemospark-cloud help`, backup, price-storage, upload, ls, download, delete).
  - [ ] All references to `BLOCKRUN_WALLET_KEY` in this repo replaced with `MNEMOSPARK_WALLET_KEY` (help, errors, config, tests).
  - [ ] `resolveOrGenerateWalletKey`: order is saved file (mnemospark then blockrun) then auto-generate; no env in resolution.
  - [ ] `resolveWalletPrivateKey`: order is MNEMOSPARK_WALLET_KEY → mnemospark file → blockrun file; error message says "No mnemospark wallet found" and mentions openclaw plugins install or MNEMOSPARK_WALLET_KEY.
  - [ ] Wallet command reads only mnemospark wallet file; export/restore text uses MNEMOSPARK_WALLET_KEY and mnemospark path.
  - [ ] All user-facing and test strings that mentioned `/cloud` now use `/mnemospark-cloud` (help, errors, proxy messages, next-step quote, tests).
  - [ ] Tests updated and passing (env var name, wallet and cloud command names, resolution order).
  - [ ] Lint and build pass.

## Task string (optional)

Work only in mnemospark repo. Implement full mnemospark command structure: (1) Replace /wallet with /mnemospark-wallet — register so users invoke /mnemospark-wallet and /mnemospark-wallet export; do not register /wallet. (2) Replace /cloud with /mnemospark-cloud — register so users invoke /mnemospark-cloud, /mnemospark-cloud help, backup, price-storage, upload, ls, download, delete; do not register /cloud. (3) Replace BLOCKRUN_WALLET_KEY with MNEMOSPARK_WALLET_KEY everywhere. (4) auth.ts: resolveOrGenerateWalletKey = saved file (mnemospark then blockrun) then auto-generate (no env). (5) cloud-command.ts: resolveWalletPrivateKey = MNEMOSPARK_WALLET_KEY then mnemospark file then blockrun file; error "No mnemospark wallet found..."; all help/error/next-step strings use /mnemospark-cloud. (6) proxy.ts and index.ts: error/help strings use /mnemospark-cloud. (7) Update cli.ts, openclaw.plugin.json, tests (including cloud-command.test.ts), and in-repo docs. Acceptance: [ ] /mnemospark-wallet and /mnemospark-cloud only; [ ] MNEMOSPARK_WALLET_KEY; [ ] resolution order; [ ] all /cloud strings → /mnemospark-cloud; [ ] tests pass; [ ] lint/build.
