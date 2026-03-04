# Code cleanup 01: Remove router and complexity

**ID:** cleanup-01  
**Repo:** mnemospark  
**Rough size:** One Cloud Agent run

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). Do **not** open, clone, or require access to mnemospark-backend, BlockRun, ClawRouter, or OpenRouter. All code is in this repo. The spec is at `.company/code_cleanup/cleanup-01-remove-router-complexity.md`.

## Scope

Remove all **LLM model routing and query-complexity** code. mnemospark does not select or route to LLM models; it provides storage + wallet + x402 per [mnemospark_full_workflow.md](../product_docs/mnemospark_full_workflow.md).

**Delete:**

- Entire directory `src/router/` (all 7 files: index.ts, selector.ts, rules.ts, llm-classifier.ts, config.ts, types.ts, selector.test.ts).
- `src/session.ts` (model selection pinning — only used by router).

**Strip usage:**

- **src/proxy.ts:** Remove all imports from `./router/index.js` (route, getFallbackChain, getFallbackChainFiltered, calculateModelCost, DEFAULT_ROUTING_CONFIG, RouterOptions, RoutingDecision, RoutingConfig, ModelPricing). Remove constants ROUTING_PROFILES, AUTO_MODEL, FREE_MODEL. Remove every code path that builds or uses `routingDecision`, `routerOpts`, routing profiles, fallback chain, or session pinning (e.g. handleChatCompletionRequest’s routing block — do not remove the whole handler in this run; only remove router/session usage so proxy still compiles; cleanup-02 will remove the chat path entirely). If proxy no longer needs SessionStore or routerOpts for any remaining path, remove those parameters from startProxy / handleChatCompletionRequest.
- **src/index.ts:** Remove import and re-exports of RoutingConfig, route, DEFAULT_ROUTING_CONFIG, getFallbackChain, getFallbackChainFiltered, calculateModelCost, RoutingDecision, RoutingConfig, Tier from router. Remove logic that injects default model `blockrun/auto` (agents.defaults.model.primary). Do not remove provider registration or /wallet / /cloud in this run.
- **src/models.ts:** Remove routing-profile aliases only: `"auto-router": "auto"` and `router: "auto"` from MODEL_ALIASES. Leave other aliases for now (cleanup-02 may remove or simplify further).

**Delete tests/scripts that only test router:**

- `test/e2e.ts` (or trim to non-router tests only; if the file only contains router tests, delete the file).
- `final-test.mjs` (ClawRouter/router test).
- `test-config-changes.mjs` (references router config).

**Result:** No remaining imports from `src/router/` or `src/session.js`. Proxy and index build; remaining tests pass.

## References

- [mnemospark_full_workflow.md](../mnemospark_full_workflow.md) — workflow (no LLM routing)
- [mnemospark_PRD.md](../product_docs/mnemospark_PRD.md) — R8 (plugin: /wallet, /cloud; no chat)
- mnemospark repo: `src/router/`, `src/session.ts`, `src/proxy.ts`, `src/index.ts`, `src/models.ts`

## Cloud Agent

- **Install (idempotent):** `pnpm install` (or project equivalent).
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] `src/router/` directory deleted (all 7 files).
  - [ ] `src/session.ts` deleted.
  - [ ] `src/proxy.ts` has no imports from `./router/` or `./session.js`; no ROUTING_PROFILES, route(), getFallbackChain, routingDecision, routerOpts, or session pinning for routing.
  - [ ] `src/index.ts` has no router imports or exports; no injection of default model `blockrun/auto`.
  - [ ] `src/models.ts` no longer contains `"auto-router"` or `router` aliases.
  - [ ] `test/e2e.ts`, `final-test.mjs`, `test-config-changes.mjs` removed (or e2e trimmed to non-router only).
  - [ ] `pnpm test` passes.
  - [ ] `pnpm build` passes.

## Task string (optional)

Work only in this repo. Remove LLM router and complexity: delete src/router/ and src/session.ts; strip all router/session imports and usage from proxy.ts and index.ts; remove routing aliases from models.ts; delete test/e2e.ts, final-test.mjs, test-config-changes.mjs. No remaining router or session imports. Acceptance: [ ] router and session deleted; [ ] proxy and index stripped; [ ] pnpm test and pnpm build pass.
