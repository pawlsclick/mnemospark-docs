# Cursor Dev: Storage upload requires prior payment record

**ID:** cursor-dev-33  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. It contains the storage upload Lambda, payment logic, and DynamoDB tables. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Refactor `/storage/upload` so that it **no longer performs direct payment verification/settlement**, and instead **requires a prior successful payment record** (from `/payment/settle`) for the given `quote_id` and `wallet_address`.

In more detail:

- In `services/storage-upload/app.py`:
  - Remove or factor out the existing EIP‑712 payment verification and on-chain/mock settlement logic (`verify_and_settle_payment`, `TransferAuthorization`, etc.).
  - Replace it with a check that, given:
    - `quote_id` and `wallet_address` from the request, and
    - any necessary environment configuration,
    the handler:
    - Looks up a **confirmed payment record** in the payment ledger table introduced by cursor-dev-32.
    - Ensures that:
      - The payment `quote_id` matches the upload `quote_id`.
      - The payment `wallet_address` matches the upload `wallet_address`.
      - The payment status indicates success and has not been consumed for upload already (if you choose to enforce one upload per payment).
  - On missing or invalid payment:
    - Return a `402 payment_required` style error **without** attempting to settle payment.
    - Include a structured error body compatible with existing client expectations (e.g. `error: "payment_required"`, plus details).
- Update the **idempotency behavior**:
  - Keep existing idempotency semantics (`UPLOAD_IDEMPOTENCY_TABLE_NAME`) for the upload itself.
  - Ensure that idempotency keys are **independent from payment**; the payment record remains the canonical source of truth for whether payment has been made for a `quote_id`.
- Keep and update the **upload transaction log**:
  - Maintain writes to `UploadTransactionLogTable` with:
    - `quote_id`, `wallet_address`, `trans_id` (payment transaction id), `storage_price`, `provider`, `location`, `bucket_name`, etc.
  - Use the payment trans_id/network/asset from the payment ledger rather than recomputing them.
- Ensure **download/housekeeping compatibility**:
  - Confirm that `storage-housekeeping` still derives payment and timing information correctly from the transaction log after this change.
  - If necessary, copy or derive any new fields it depends on from the payment record into the transaction log.
- Integrate with the `api-calls` logger:
  - Ensure that `lambda_handler` and `confirm_upload_handler` log calls (success and key error paths) using the helper from cursor-dev-31.

Depends on:
- cursor-dev-31 (Backend API call logging to DynamoDB) for the shared `api-calls` logger.
- cursor-dev-32 (Backend payment settlement endpoint) for the payment ledger and new `/payment/settle` behavior.

## References

- `services/storage-upload/app.py` (current upload and payment flow, idempotency, and transaction log).
- `template.yaml` (DynamoDB table names and IAM configuration).
- `services/storage-housekeeping/app.py` (billing enforcement logic that reads from the transaction log).
- `dev_docs/features_cursor_dev/cursor-dev-31-backend-api-call-logging-dynamodb.md`.
- `dev_docs/features_cursor_dev/cursor-dev-32-backend-payment-settle-endpoint.md`.

## Agent

- **Install (idempotent):** `pip install -r requirements.txt || true`
- **Start (if needed):** None.
- **Secrets:** None needed for static implementation and local tests; on-chain settlement remains in `/payment/settle` and is already covered there.
- **Acceptance criteria (checkboxes):**
  - [ ] `/storage/upload` no longer performs direct EIP‑712 payment verification or settlement.
  - [ ] `/storage/upload` requires a confirmed payment record for `(wallet_address, quote_id)` and returns a 402-style error when missing.
  - [ ] Upload idempotency still works as before for retries.
  - [ ] Upload transaction logs include payment trans_id/network/asset populated from the payment ledger.
  - [ ] `storage-housekeeping` continues to function correctly for billing enforcement using the updated transaction log.
  - [ ] `storage-upload` handlers use the `api-calls` logger for success and error paths.

## Task string (optional)

Work only in the `mnemospark-backend` repo. Refactor `services/storage-upload/app.py` so that payment verification and settlement are entirely delegated to the `/payment/settle` endpoint and its ledger; `/storage/upload` must simply assert that a valid, confirmed payment exists for the `(wallet_address, quote_id)` pair and proceed or reject accordingly. Preserve idempotency and transaction logging semantics, ensure billing housekeeping continues to work based on the log, and wire `storage-upload` into the shared `api-calls` logger. Acceptance: [ ] upload requires a prior payment record, [ ] no inline payment settlement remains, [ ] logging and housekeeping remain correct.

