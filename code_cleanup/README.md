# Code cleanup: mnemospark workflow-only (Cursor Cloud Agent)

Right-sized execution plan for **Cursor Cloud Agents** to prune the mnemospark repo to workflow-only behavior. mnemospark does **not** provide chat; it provides **storage + wallet + x402 payment** per [mnemospark_full_workflow.md](../mnemospark_full_workflow.md) and [mnemospark_PRD.md](../mnemospark_PRD.md).

**Product context:** [mnemospark_PRD.md](../mnemospark_PRD.md), [mnemospark_full_workflow.md](../mnemospark_full_workflow.md). Design pattern: [features_cursor_dev/README.md](../features_cursor_dev/README.md).

---

## How to use

1. Run Cloud Agent from the **mnemospark** repo only.
2. Ensure the **mnemospark-docs** submodule is populated: in mnemospark run `git submodule update --init` (or clone with `--recurse-submodules`). Specs live under `.company/code_cleanup/`.
3. Run cleanup in order: **01 → 02 → 03**. After each run, verify tests and build (acceptance criteria).
4. Use the **task string** from the feature file (or point the agent at `.company/code_cleanup/cleanup-01-remove-router-complexity.md` etc.).

**Path when running from mnemospark:** `.company/code_cleanup/<feature-file>.md`

---

## Ordering / dependencies

| Order | ID   | File | Description |
| ----- | ---- | ---- | ----------- |
| 1     | 01   | [cleanup-01-remove-router-complexity.md](cleanup-01-remove-router-complexity.md) | Remove router and complexity (required). Delete `src/router/`, `src/session.ts`; strip from proxy, index, models; remove router-only tests. |
| 2     | 02   | [cleanup-02-remove-chat-completions.md](cleanup-02-remove-chat-completions.md) | Remove all `/v1/chat/completions` handling. Proxy only serves mnemospark-backend paths + health. Remove LLM-only modules and BlockRun provider. |
| 3     | 03   | [cleanup-03-docs-metadata.md](cleanup-03-docs-metadata.md) | Align package.json, openclaw.plugin.json, openclaw.security.json, README with PRD (no "Smart LLM router", no chat). |

**Verification:** Each run’s acceptance criteria include **pnpm test** and **pnpm build** pass. Run 02 is the largest; 01 and 03 are smaller. Splitting into three runs keeps each Cloud Agent run focused and testable.

---

## Conventions

Each cleanup file includes:

- **ID, Repo, Rough size** — one Cloud Agent run.
- **Scope** — what to change in this run only.
- **References** — PRD, workflow, and (for 01/02) code locations.
- **Cloud Agent** — install (idempotent), start (if needed), secrets, **acceptance criteria (checkboxes)**.
- **Task string (optional)** — copy-paste prompt for the agent.

---

## Out of scope (do not remove)

- **Workflow-supporting:** `/cloud` commands (backup, price-storage, upload, ls, download, delete), `/wallet`, proxy forwarding to mnemospark-backend (price-storage, storage/upload, storage/ls, storage/download, storage/delete), wallet signing (X-Wallet-Signature), [mnemospark_full_workflow.md](../mnemospark_full_workflow.md).
- **x402 payment:** mnemospark submits payment using x402; keep payment/submission code that supports storage flows (e.g. upload balance check, payment signing for backend).
- **Auth, config, balance, wallet:** [auth](mnemospark/src/auth.ts), [config](mnemospark/src/config.ts), [balance](mnemospark/src/balance.ts) (used for upload balance and /wallet).
