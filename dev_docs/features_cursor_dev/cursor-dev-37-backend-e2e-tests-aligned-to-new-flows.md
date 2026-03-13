# Cursor Dev: Backend end-to-end tests aligned to new flows

**ID:** cursor-dev-37  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. It contains all backend handlers and tests. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Update or add **end-to-end and integration tests** so they are fully aligned with the revised backend behavior:

- Strict wallet proof enforcement on all endpoints.
- Separate `/payment/settle` endpoint.
- `/storage/upload` requiring prior payment.
- New logging tables and schemas (where observable).

In more detail:

- Identify existing tests under `tests/` (or equivalent) that:
  - Exercise `/price-storage`, `/storage/upload`, `/storage/ls`, `/storage/download`, `/storage/delete`.
  - Use local SAM (`sam local invoke` / `sam local start-api`) or mocked AWS clients.
- Update tests to:
  - Use **valid wallet proofs** (or appropriate mocks) for all wallet-scoped endpoints.
  - Follow the new **happy-path flow**:
    - Call `/price-storage` to obtain a quote.
    - Call `/payment/settle` with a valid payment authorization for that quote.
    - Call `/storage/upload` (and `/storage/upload/confirm` for presigned mode) for the same `quote_id` and `wallet_address`.
    - Optionally call `/storage/ls`, `/storage/download`, `/storage/delete` to verify stored objects.
  - Include negative tests:
    - Missing/invalid wallet proof (expect 403).
    - Upload without prior payment (expect 402 with `payment_required`).
    - Mismatched wallet or quote IDs between payment and upload.
- Where feasible without requiring real chain access:
  - Stub or mock payment verification / settlement for tests, especially on-chain paths.
  - Use mock modes and environment flags already supported by the code.
- Optionally add tests (or test helpers) that verify:
  - `wallet-auth-events` table entries are written for authorizer decisions.
  - `api-calls` table entries exist for successful and failed calls.
  - Transaction logs and payment ledger records are created and consumed as expected.

Depends on:
- cursor-dev-30–35 (wallet proof enforcement, logging, payment endpoint, upload refactor, IAM).
- cursor-dev-32 and cursor-dev-33 in particular for the new payment+upload flow.

## References

- Existing tests under `tests/` in mnemospark-backend.
- `services/price-storage/app.py`, `services/storage-upload/app.py`, `services/storage-ls/app.py`, `services/storage-download/app.py`, `services/storage-delete/app.py`, `services/payment-settle/app.py`.
- `mnemospark-docs/meta_docs/wallet-proof.md`.
- `dev_docs/features_cursor_dev/cursor-dev-30-backend-wallet-proof-enforcement-and-auth-logging.md`.
- `dev_docs/features_cursor_dev/cursor-dev-31-backend-api-call-logging-dynamodb.md`.
- `dev_docs/features_cursor_dev/cursor-dev-32-backend-payment-settle-endpoint.md`.
- `dev_docs/features_cursor_dev/cursor-dev-33-backend-storage-upload-require-payment-record.md`.

## Agent

- **Install (idempotent):** `pip install -r requirements.txt || true`
- **Start (if needed):** `pytest -v` (or a more specific test command you identify in this repo).
- **Secrets:** None required for unit and mocked integration tests; if you add any tests that require real AWS credentials, clearly mark them as optional and gated behind environment variables.
- **Acceptance criteria (checkboxes):**
  - [ ] Tests cover the primary happy-path flow: price → payment → upload → confirm (if presigned) → ls/download/delete.
  - [ ] Tests cover key failure modes: missing/invalid wallet proof, missing payment, mismatched wallet/quote, and representative 4xx/5xx errors.
  - [ ] Tests pass reliably in CI without requiring real chain access by default.
  - [ ] Where practical, tests assert that new logging tables (`wallet-auth-events`, `api-calls`, payment ledger, transaction log) receive expected records.

## Task string (optional)

Work only in the `mnemospark-backend` repo. Extend and update backend tests so that they fully exercise the new wallet proof enforcement, `/payment/settle` behavior, and `/storage/upload` requirement for prior payment, including both happy paths and key error scenarios, while keeping tests suitable for CI by default. Acceptance: [ ] happy-path pricing/payment/upload flow covered, [ ] major error paths tested, [ ] tests pass without real chain access by default.

