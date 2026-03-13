# Cursor Dev: Backend payment settlement endpoint

**ID:** cursor-dev-32  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. It contains the SAM template, Lambda handlers, and DynamoDB schemas for pricing, uploads, and housekeeping. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Introduce a dedicated **payment settlement API endpoint**, `POST /payment/settle`, that verifies EIP‑712 payment authorizations, performs settlement (mock or on-chain), and records payment results in DynamoDB, enforcing **one quote → one payment per wallet**.

In more detail:

- Design and implement a new Lambda handler under `services/` (e.g. `services/payment-settle/app.py`) that:
  - Accepts a JSON body containing at least:
    - `quote_id`
    - `wallet_address`
    - A payment authorization payload compatible with the current `storage-upload` payment logic (e.g. header-style or inline JSON).
  - Uses the same EIP‑712 TransferWithAuthorization verification semantics currently implemented in `services/storage-upload/app.py`:
    - Network, asset, recipient, amount validation.
    - Time bounds (`validAfter`, `validBefore`).
    - Signature recovery and wallet address match.
  - Honors the existing environment-driven settlement mode:
    - `MNEMOSPARK_PAYMENT_SETTLEMENT_MODE=mock|onchain`.
    - Uses the configured Base RPC and relayer key when on-chain.
- Introduce a **payment ledger table** in `template.yaml` (for example, `${StackName}-payments`) or extend the existing `UploadTransactionLogTable` if that is preferred (choose one and document it in the code and comments):
  - Enforce **one (wallet_address, quote_id)** → one successful payment:
    - Use a key schema and/or conditional writes to prevent duplicate confirmed payments for the same quote and wallet.
  - Store:
    - `quote_id`, `wallet_address`, `trans_id`, `network`, `asset`, `amount`, `payment_status`, `timestamp`, and any relevant metadata.
- Wire the new Lambda into API Gateway via `template.yaml`:
  - Add `POST /payment/settle` under the existing `MnemosparkBackendApi` with:
    - `Auth` using the wallet authorizer.
    - A request model referencing the expected JSON shape.
- Integrate with shared logging:
  - Call the `api-calls` logging helper (from cursor-dev-31) so each `/payment/settle` invocation is recorded with status and result.
- Ensure **responses and errors** are consistent with the rest of the backend:
  - 200 on success, including `quote_id`, `wallet_address`, `trans_id`, and payment details.
  - 4xx for validation / authorization issues, 5xx for unexpected errors.

Depends on:
- cursor-dev-29 (Backend OAS 3.2 skeleton and endpoint inventory) to align the new path and operation definition.
- cursor-dev-30 (Wallet proof enforcement and authorizer logging) so `/payment/settle` is covered by the wallet authorizer.
- cursor-dev-31 (API call logging) for the shared logging helper and `api-calls` table.

## References

- `services/storage-upload/app.py` (current EIP‑712 payment verification and settlement flow).
- `template.yaml` (existing Lambda definitions, IAM roles, and DynamoDB tables).
- `dev_docs/features_cursor_dev/cursor-dev-29-backend-oas-skeleton-and-inventory.md`.
- `dev_docs/features_cursor_dev/cursor-dev-30-backend-wallet-proof-enforcement-and-auth-logging.md`.
- `dev_docs/features_cursor_dev/cursor-dev-31-backend-api-call-logging-dynamodb.md`.

## Agent

- **Install (idempotent):** `pip install -r requirements.txt || true`
- **Start (if needed):** None.
- **Secrets:** None required for static implementation and unit tests. If you add integration tests for on-chain mode, gate them behind environment variables and document that they require valid Base RPC + relayer key.
- **Acceptance criteria (checkboxes):**
  - [ ] A new `POST /payment/settle` Lambda and API Gateway route are defined in `template.yaml` and deployed via SAM.
  - [ ] The new handler validates and settles payments using the same EIP‑712 semantics as the existing upload payment logic.
  - [ ] A payment ledger table or extended transaction log exists and prevents duplicate confirmed payments for the same `(wallet_address, quote_id)`.
  - [ ] Successful and failed `/payment/settle` calls are recorded in the `api-calls` table via the shared logging helper.
  - [ ] Responses use consistent status codes and error structures with the rest of the backend.

## Task string (optional)

Work only in the `mnemospark-backend` repo. Add a new `POST /payment/settle` Lambda and API Gateway route that verifies EIP‑712 payment authorizations, performs mock or on-chain settlement according to environment, and writes a persistent payment record enforcing one `(wallet_address, quote_id)`→one payment. Reuse and refactor the existing payment logic from `services/storage-upload/app.py`, integrate with the `api-calls` logger, and update `template.yaml` with the new function, table, and IAM. Acceptance: [ ] endpoint available and secured by wallet proof, [ ] payments verified and stored, [ ] duplicate payments prevented per quote/wallet, [ ] structured logging in DynamoDB and CloudWatch.

