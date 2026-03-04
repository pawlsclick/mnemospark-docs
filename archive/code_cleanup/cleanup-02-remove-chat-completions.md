# Code cleanup 02: Remove chat completions and LLM-only code

**ID:** cleanup-02  
**Repo:** mnemospark  
**Rough size:** One Cloud Agent run

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). Do **not** open, clone, or require access to mnemospark-backend, BlockRun, ClawRouter, or OpenRouter. The spec is at `.company/code_cleanup/cleanup-02-remove-chat-completions.md`.

## Scope

mnemospark does **not** provide chat. Remove all `/v1/chat/completions` handling from the proxy. Proxy must **only** serve:

- Mnemospark-backend paths: `/mnemospark/price-storage`, `/mnemospark/storage/upload`, `/mnemospark/storage/ls`, `/mnemospark/storage/download`, `/mnemospark/storage/delete` (forward to MNEMOSPARK_BACKEND_API_BASE_URL with wallet signing).
- Health and any minimal admin endpoints (e.g. `/health`) needed for OpenClaw.

**Remove from proxy:**

- Entire handling of `/v1/chat/completions` (e.g. the branch that forwards to BlockRun API, handleChatCompletionRequest or equivalent). Do not register or handle that path.
- All code and parameters used only by the chat path: ResponseCache, RequestDeduplicator, BalanceMonitor (if only used for LLM balance in chat path — **keep** BalanceMonitor if used for upload balance check), SessionJournal, compressContext/shouldCompress (compression), logUsage for LLM (logger), getStats for LLM usage, payment-cache for x402 chat. Remove only what is **exclusively** for the LLM/chat flow; **keep** x402 and balance code that supports storage (e.g. upload balance check, payment submission for storage).

**Remove or simplify:**

- **BlockRun provider:** Remove registration of BlockRun as an LLM provider (no OPENCLAW_MODELS, no models.providers.blockrun injection in index). Plugin no longer exposes an LLM provider; commands are /wallet and /cloud only.
- **src/index.ts:** Remove /stats command registration. Remove exports for ResponseCache, RequestDeduplicator, getStats, SessionStore, router types (already removed in 01). Remove injectModelsConfig (or equivalent) that writes BlockRun models into OpenClaw config. Keep: /wallet, /cloud, proxy start, service stop, auth/config/balance as needed for workflow.
- **src/provider.ts:** Remove or stub: plugin no longer provides an LLM provider (see PRD: storage + wallet, no chat).
- **src/models.ts:** Can be removed or reduced to a minimal stub if nothing else needs it (e.g. buildProviderModels only used by provider).

**Delete LLM-only modules (if no longer referenced):**

- `src/response-cache.ts` (and `src/response-cache*.test.ts`).
- `src/dedup.ts`.
- `src/compression/` (entire directory).
- `src/journal.ts` (and `src/journal.test.ts` if only for journal).
- `src/logger.ts` if only used for LLM usage logging (remove or keep only if used for storage/proxy logging).
- `src/stats.ts` (LLM usage stats).
- `src/payment-cache.ts` if only used for chat x402 (keep if used for storage payment flow).
- `src/updater.ts` if only for “check for updates” in chat context.

**Keep:**

- x402 payment submission used by storage (e.g. upload payment).
- BalanceMonitor where used for upload balance check.
- Wallet signing (mnemospark-request-sign, wallet-signature) for backend requests.
- Proxy HTTP server, health, and all mnemospark-backend forwarding routes.

**Result:** Proxy listens only for mnemospark-backend paths and health; no chat completions; no BlockRun provider; all tests pass.

## References

- [mnemospark_full_workflow.md](../mnemospark_full_workflow.md) — proxy forwards to backend only; no chat.
- [mnemospark_PRD.md](../product_docs/mnemospark_PRD.md) — R8 (commands /wallet, /cloud; no chat provider).
- mnemospark repo: `src/proxy.ts`, `src/index.ts`, `src/provider.ts`, `src/models.ts`, and LLM-only modules listed above.

## Cloud Agent

- **Install (idempotent):** `pnpm install`.
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] Proxy does not handle `/v1/chat/completions`; only mnemospark-backend paths (price-storage, storage/upload, ls, download, delete) and health (or minimal admin).
  - [ ] BlockRun provider and model injection removed from index; no OPENCLAW_MODELS / models.providers.blockrun.
  - [ ] /stats command removed from index.
  - [ ] LLM-only modules removed (response-cache, dedup, compression, journal, stats, and optionally logger/payment-cache/updater if only used for chat).
  - [ ] provider.ts removed or stubbed (no LLM provider).
  - [ ] x402 and BalanceMonitor kept where used for storage/wallet (e.g. upload balance, payment submission).
  - [ ] `pnpm test` passes.
  - [ ] `pnpm build` passes.

## Task string (optional)

Work only in this repo. mnemospark does not provide chat. Remove all /v1/chat/completions from proxy; proxy only serves mnemospark-backend paths and health. Remove BlockRun provider, /stats, and LLM-only modules (response-cache, dedup, compression, journal, stats, etc.). Keep x402 and balance for storage. Acceptance: [ ] no chat path; [ ] no provider; [ ] pnpm test and pnpm build pass.
