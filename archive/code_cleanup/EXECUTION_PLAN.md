# Code cleanup execution plan (summary)

Right-sized for **Cursor Cloud Agents**. Run from **mnemospark** repo; specs under `.company/code_cleanup/`.

## Decisions (from plan feedback)

1. **Remove router and complexity (required)** — Agreed. Delete `src/router/`, `src/session.ts`; strip all router/session usage from proxy, index, models; remove router-only tests.
2. **Chat completions** — mnemospark does **not** provide chat. Remove all `/v1/chat/completions` handling. Proxy only serves mnemospark-backend paths (price-storage, storage/upload, ls, download, delete), health, and minimal admin.
3. **Keep (workflow-supporting)** — Agreed. mnemospark also submits payment using **x402**; keep x402 and balance code that supports storage (e.g. upload balance check, payment signing).
4. **Docs and metadata** — Align with [mnemospark_PRD.md](../product_docs/mnemospark_PRD.md).
5. **Implementation order** — Logical: 01 (router/complexity) → 02 (chat + LLM-only code) → 03 (docs/metadata).
6. **Risk and testing** — Ensure **all tests pass** after each run; acceptance criteria include `pnpm test` and `pnpm build`.

## Runs

| # | File | One-run scope |
|---|------|----------------|
| 1 | [cleanup-01-remove-router-complexity.md](cleanup-01-remove-router-complexity.md) | Delete router + session; strip from proxy/index/models; delete router-only tests. |
| 2 | [cleanup-02-remove-chat-completions.md](cleanup-02-remove-chat-completions.md) | Remove /v1/chat/completions and LLM-only modules; proxy backend-only; no BlockRun provider. |
| 3 | [cleanup-03-docs-metadata.md](cleanup-03-docs-metadata.md) | package.json, openclaw.*.json, README aligned with PRD. |

See [README.md](README.md) for how to use and path (`.company/code_cleanup/<file>.md` when running from mnemospark).
