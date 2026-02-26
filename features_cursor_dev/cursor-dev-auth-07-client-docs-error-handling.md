# Cursor Dev: Client/docs — remove API key, error handling for 401/403

**ID:** auth-07  
**Repo:** mnemospark  
**Rough size:** One Cloud Agent run

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). Client and docs are in this repo. Do **not** open, clone, or require access to BlockRun/ClawRouter, OpenRouter, or any other repository; all code and references are in this repo and `.company/`.

## Scope

**Config/secrets:** Remove any mention of "API base URL and x-api-key" for proxy→backend from user-facing config, env docs, and secrets guidance. User config is: API base URL (or default) and wallet (already required for upload and BlockRun). No backend API key to set. **User-facing args:** price-storage, upload, ls, download, delete unchanged; proxy adds wallet signature (auth-06). **Error messages:** When backend returns 401/403, show clear message (e.g. "Wallet signature invalid or expired"; "Cannot price storage" / "Cannot upload" etc. as today). **Docs (mnemospark repo only):** Update only **in-repo** README, env docs, and secrets guidance (no backend API key). Add a short note that backend authentication is wallet proof (no shared API key); the canonical API spec is in the mnemospark-docs repo. **Do not** edit the `.company` directory (mnemospark-docs submodule). The update to mnemospark_backend_api_spec.md §1 (wallet-proof auth, CORS, verifyingContract) is done **only in mnemospark-docs** in a separate change (e.g. after auth-02/auth-04 or in a docs-only PR). Ref: [auth_no_api_key_wallet_proof_spec.md](../auth_no_api_key_wallet_proof_spec.md) §4.4, §5, §3.4.

## References

- [auth_no_api_key_wallet_proof_spec.md](../auth_no_api_key_wallet_proof_spec.md) §4.4 (error handling), §5 (client), §3.4 (API spec)
- [mnemospark_backend_api_spec.md](../mnemospark_backend_api_spec.md) — §1 updated in mnemospark-docs only (not in this task)
- [mnemospark_full_workflow.md](../mnemospark_full_workflow.md) — user commands

## Cloud Agent

- **Install (idempotent):** None.
- **Start (if needed):** None.
- **Secrets:** None (docs say no backend API key).
- **Acceptance criteria (checkboxes):**
  - [ ] Config/docs: no reference to setting or passing MNEMOSPARK_BACKEND_API_KEY or x-api-key for proxy→backend; user config = API base URL + wallet.
  - [ ] Client error handling: 401/403 from backend produce clear user message (e.g. "Wallet signature invalid or expired", or existing "Cannot price storage" / "Cannot upload" etc. as appropriate).
  - [ ] README or env docs updated: list required env (e.g. MNEMOSPARK_BACKEND_API_BASE_URL, wallet); explicitly state no backend API key needed.
  - [ ] In mnemospark repo only: README or env docs list required env (e.g. MNEMOSPARK_BACKEND_API_BASE_URL, wallet); state that no backend API key is needed; add a short note that backend auth is wallet proof and the API spec is in mnemospark-docs. Do not edit .company.
  - [ ] No code paths that prompt for or validate backend API key for mnemospark.

## Task string (optional)

Work only in this repo. Remove API key from client config and docs: user config = API base URL + wallet; no backend API key. Error messages for 401/403: clear (e.g. wallet signature invalid/expired, Cannot price storage/upload). Update README/env docs for wallet-proof auth. Do not edit .company; API spec §1 is updated in mnemospark-docs only. Ref: auth_no_api_key_wallet_proof_spec.md §4.4, §5, §3.4. Acceptance: [ ] no API key in config/docs; [ ] 401/403 messages; [ ] README/env note; do not edit .company.
