# Cursor Dev: Logging hardening and housekeeping alignment

**ID:** cursor-dev-34  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. It contains all Lambda handlers, the housekeeping function, and CloudWatch/CloudTrail configuration. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Ensure **robust, structured logging** for all Lambda functions to CloudWatch (correlatable with CloudTrail) and align the `storage-housekeeping` billing enforcement logic with the new payment and upload flows.

In more detail:

- For all public-facing Lambda handlers:
  - `services/price-storage/app.py`
  - `services/storage-upload/app.py` (`lambda_handler` and `confirm_upload_handler`)
  - `services/storage-ls/app.py`
  - `services/storage-download/app.py`
  - `services/storage-delete/app.py`
  - `services/payment-settle/app.py` (from cursor-dev-32)
  - Review existing logging calls and:
    - Ensure they emit **JSON-serializable payloads** with:
      - A top-level `event` field (e.g. `price_request_parsed`, `upload_request_parsed`, `payment_settlement_succeeded`).
      - Key identifiers: `request_id` (if available), `wallet_address`, `quote_id`, `trans_id`, `path`, `method`, `status`.
      - Concise error codes and messages for failure paths.
    - Avoid logging sensitive material (private keys, raw signatures, ciphertext, secrets).
- For the **wallet authorizer**:
  - Confirm that structured debug logs from cursor-dev-30 include information sufficient to correlate authorizer decisions with:
    - API Gateway requests (via `methodArn`/`routeArn` and request IDs).
    - Downstream Lambda logs (via normalized path and wallet address).
- For **`services/storage-housekeeping/app.py`**:
  - Review how it currently:
    - Reads from `UploadTransactionLogTable`.
    - Determines latest confirmed payment per object (`trans_id`, `payment_received_at`, etc.).
  - Align its expectations with the **post-refactor upload and payment model**:
    - Ensure that fields it uses (e.g. `recipient_wallet`, `payment_received_at`, `payment_amount`, `location`, `bucket_name`, `object_key`) are still populated correctly after cursor-dev-32 and cursor-dev-33 changes.
    - If needed, extend the transaction log writes in `storage-upload` and `/payment/settle` so housekeeping has a stable, well-documented schema to operate on.
  - Confirm that dry-run vs enforcement behavior remains correct (no functional change to the schedule).
- Add or update documentation comments (in code or a small `docs/` note) describing:
  - The logging conventions (event names, core fields).
  - How CloudWatch logs and DynamoDB logging (`wallet-auth-events`, `api-calls`, payment ledger, transaction log) can be correlated with CloudTrail for incident investigations.

Depends on:
- cursor-dev-30 (Wallet proof enforcement and authorizer logging).
- cursor-dev-31 (API call logging to DynamoDB).
- cursor-dev-32 (Payment settlement endpoint).
- cursor-dev-33 (Storage upload requires prior payment record).

## References

- `services/price-storage/app.py`.
- `services/storage-upload/app.py`.
- `services/storage-ls/app.py`, `services/storage-download/app.py`, `services/storage-delete/app.py`.
- `services/payment-settle/app.py`.
- `services/storage-housekeeping/app.py`.
- `template.yaml` (CloudWatch log group configuration, CloudTrail resources).
- `dev_docs/features_cursor_dev/cursor-dev-30-backend-wallet-proof-enforcement-and-auth-logging.md`.
- `dev_docs/features_cursor_dev/cursor-dev-31-backend-api-call-logging-dynamodb.md`.

## Agent

- **Install (idempotent):** `pip install -r requirements.txt || true`
- **Start (if needed):** None.
- **Secrets:** None (no live AWS calls required; rely on local tests and static analysis).
- **Acceptance criteria (checkboxes):**
  - [ ] All public-facing handlers emit structured JSON logs with consistent `event` names and core fields (wallet, path, method, status, error code).
  - [ ] No sensitive material (private keys, raw signatures, ciphertext) is logged.
  - [ ] The wallet authorizer’s logs can be correlated with downstream handler logs using method/path and wallet context.
  - [ ] `storage-housekeeping` correctly interprets the updated upload transaction records after the payment/upload refactors.
  - [ ] A short doc or code-level documentation describes logging conventions and how they relate to CloudTrail.

## Task string (optional)

Work only in the `mnemospark-backend` repo. Harden structured logging for all public-facing handlers and the wallet authorizer to ensure JSON-friendly, correlatable logs suitable for security and billing investigations, and update `storage-housekeeping` so it stays consistent with the new payment+upload transaction schema. Do not change API behavior beyond logging and schema alignment. Acceptance: [ ] structured logs across Lambdas, [ ] housekeeping still enforces billing correctly with the updated transaction log.

