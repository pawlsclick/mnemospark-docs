# Cursor Dev: Presigned Upload Confirmation Endpoint (Backend)

**ID:** fix-07
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. This is the serverless AWS Lambda backend using AWS SAM. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

For **presigned uploads**, the backend currently settles payment, generates a presigned S3 PUT URL, writes the transaction log, deletes the consumed quote, and marks idempotency `completed` -- all before the client has actually uploaded the file to S3. This means:

- The transaction log records success even if the client never completes the S3 PUT.
- The consumed quote is deleted, so the client cannot get a new one to retry.
- The idempotency record is `completed`, so re-calling `/storage/upload` with the same key just returns the cached (false-positive) success.

This fix introduces a two-phase presigned upload flow:

1. **Phase 1** (`POST /storage/upload` with `mode: "presigned"`): settle payment, generate presigned URL, mark idempotency as `pending_confirmation` (a new status), and return the presigned URL **without** writing the transaction log or deleting the quote.
2. **Phase 2** (`POST /storage/upload/confirm`): client calls this after successfully PUTting to S3. The confirm handler verifies the S3 object exists (via `head_object`), writes the transaction log, deletes the consumed quote, and marks idempotency `completed`.

### Changes required

**`services/storage-upload/app.py`**

1. **New idempotency status `pending_confirmation`**: Add a new function `_mark_idempotency_pending_confirmation()` similar to `_mark_idempotency_completed()` (line 1078) but with `"status": "pending_confirmation"`. It should also store `payment_result` fields (trans_id, network, asset, amount) and `quote_context` fields (storage_price, provider, location) in the item so Phase 2 can restore them. Also store `response_body` for the cached response.

2. **Modify presigned branch in `lambda_handler()`** (lines 1431-1452): After generating the presigned URL at line 1436-1444, instead of falling through to the transaction log write at line 1535:
   - Build the `response_body` (same as lines 1563-1580).
   - Build the `payment_response_header` (same as lines 1581-1588).
   - Call `_mark_idempotency_pending_confirmation()` instead of `_mark_idempotency_completed()`.
   - **Do NOT** call `_write_transaction_log()`.
   - **Do NOT** delete the consumed quote.
   - Return 200 with `response_body` and `upload_url` immediately.
   - Add a `"confirmation_required": True` field to `response_body` so the client knows to call confirm.

3. **New handler function `confirm_upload_handler(event, context)`**: A separate Lambda handler for `POST /storage/upload/confirm`. This handler should:
   - Parse input: requires `wallet_address`, `object_key`, `idempotency_key`, `quote_id` (all strings, from JSON body).
   - Run `_require_authorized_wallet()` same as the upload handler.
   - Look up the idempotency record by `idempotency_key`. Verify status is `pending_confirmation` and `request_hash` matches (compute from supplied fields). If `completed`, return cached success. If not found or wrong status, return 404/409.
   - Verify the S3 object exists via `head_object` on bucket `mnemospark-{sha256(wallet_address)[:16]}` key `object_key`. If the object does not exist, return 404 with `"error": "S3 object not found. Upload the file using the presigned URL first."`.
   - Restore `payment_result` and `quote_context` from the idempotency record.
   - Call `_write_transaction_log()`.
   - Delete the consumed quote (best-effort).
   - Call `_mark_idempotency_completed()`.
   - Return 200 with the same response body (without `upload_url`).
   - Use structured logging via `_log_event()` at key points: `confirm_request_parsed`, `confirm_s3_object_verified`, `confirm_transaction_log_written`, `confirm_completed`.

4. **Handle `pending_confirmation` in `lambda_handler()` idempotency check**: In the idempotency check section (lines 1308-1397), when the existing record has `status == "pending_confirmation"`:
   - Regenerate a fresh presigned URL (same as the current `_cached_success_response` logic for presigned mode).
   - Return 200 with the response body, `upload_url`, and `confirmation_required: True`.
   - This covers the case where the client requests a new presigned URL because the previous one expired.

**`template.yaml`**

5. **New API Gateway model `UploadConfirmRequest`**: Add a model with required fields: `wallet_address` (string), `object_key` (string), `idempotency_key` (string), `quote_id` (string).

6. **New Lambda function `StorageUploadConfirmFunction`**: Add under `Resources`. Should:
   - Use the same `CodeUri: services/storage-upload` (same code directory, different handler).
   - Handler: `app.confirm_upload_handler`.
   - Role: Same as `StorageUploadFunction` (needs S3 HeadObject, DynamoDB read/write on same tables).
   - Environment variables: Same as `StorageUploadFunction` (needs `QUOTES_TABLE_NAME`, `UPLOAD_TRANSACTION_LOG_TABLE_NAME`, `UPLOAD_IDEMPOTENCY_TABLE_NAME`).
   - Event: `POST /storage/upload/confirm` on the same API with `WalletRequestAuthorizer`.
   - RequestModel: `UploadConfirmRequest`, `ValidateBody: true`.
   - Request headers: `Idempotency-Key` (optional), wallet signature headers.

### Notes

- The inline upload path is **unchanged** -- it still writes the transaction log and marks idempotency `completed` immediately after `_upload_ciphertext_to_s3()` succeeds.
- The 207 S3-failure-after-payment path (fix-04) is **unchanged** -- it only applies to inline mode.
- The presigned URL TTL (`PRESIGNED_URL_EXPIRES_IN_SECONDS = 3600`) remains unchanged.
- If the client never calls `/storage/upload/confirm`, the idempotency record expires after `IDEMPOTENCY_TTL_SECONDS` (24 hours) and the quote remains in the quotes table (it has its own TTL).

## References

- `services/storage-upload/app.py` lines 30-31: logger initialization
- `services/storage-upload/app.py` lines 43-44: `IDEMPOTENCY_TTL_SECONDS`, `PRESIGNED_URL_EXPIRES_IN_SECONDS`
- `services/storage-upload/app.py` lines 138-153: `ParsedUploadRequest` dataclass (fields: `mode`, `content_sha256`, `ciphertext`, `wrapped_dek`, `content_length_bytes`, etc.)
- `services/storage-upload/app.py` lines 186-189: `_log_event()` structured logging helper
- `services/storage-upload/app.py` lines 414-424: `_presigned_put_object_params()` helper
- `services/storage-upload/app.py` lines 795-796: `_settlement_mode()` -- defaults to `"onchain"`
- `services/storage-upload/app.py` lines 963-986: `_request_fingerprint()` -- handles `ciphertext is None` for presigned mode
- `services/storage-upload/app.py` lines 1078-1096: `_mark_idempotency_completed()` -- model for the new `_mark_idempotency_pending_confirmation()`
- `services/storage-upload/app.py` lines 1099-1130: `_mark_idempotency_upload_retryable()` -- stores payment/quote context in idempotency record
- `services/storage-upload/app.py` lines 1132-1173: `_payment_result_from_retryable_idempotency()` and `_quote_context_from_retryable_idempotency()` -- restore state from idempotency record (reuse pattern for confirm handler)
- `services/storage-upload/app.py` lines 1184-1210: `_cached_success_response()` -- regenerates presigned URLs on cache hit
- `services/storage-upload/app.py` lines 1272-1610: `lambda_handler()` -- the presigned branch is at lines 1431-1452
- `services/storage-upload/app.py` lines 1535-1561: transaction log write and quote deletion (must be deferred for presigned mode)
- `services/storage-upload/app.py` lines 1563-1610: response body construction and idempotency completion
- `template.yaml` lines 377-409: `StorageUploadRequest` API Gateway model
- `template.yaml` lines 548-589: `StorageUploadFunction` resource definition (use as template for new function)
- `template.yaml` lines 567-589: StorageUploadPost event (use as template for new confirm event)
- S3 `head_object` API: https://docs.aws.amazon.com/AmazonS3/latest/API/API_HeadObject.html

## Agent

- **Install (idempotent):** `pip install -r services/storage-upload/requirements.txt`
- **Start (if needed):** None.
- **Secrets:** None for unit tests. For integration tests: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`.
- **Acceptance criteria (checkboxes):**
  - [ ] New function `_mark_idempotency_pending_confirmation()` stores payment result, quote context, and response body in the idempotency record with status `"pending_confirmation"`
  - [ ] Presigned branch in `lambda_handler()` calls `_mark_idempotency_pending_confirmation()` instead of `_mark_idempotency_completed()`
  - [ ] Presigned branch does NOT call `_write_transaction_log()` or delete the quote
  - [ ] Presigned branch response body includes `"confirmation_required": true`
  - [ ] `lambda_handler()` idempotency check handles `pending_confirmation` status: regenerates fresh presigned URL and returns 200 with `confirmation_required: true`
  - [ ] New `confirm_upload_handler()` function: parses input, verifies wallet, checks idempotency `pending_confirmation` status, verifies S3 object via `head_object`, writes transaction log, deletes consumed quote, marks idempotency `completed`, returns 200
  - [ ] `confirm_upload_handler()` returns 404 if S3 object does not exist
  - [ ] `confirm_upload_handler()` returns cached success if idempotency status is already `completed`
  - [ ] Structured logging in `confirm_upload_handler()` at key decision points
  - [ ] `template.yaml` has new `UploadConfirmRequest` model with required fields
  - [ ] `template.yaml` has new `StorageUploadConfirmFunction` resource with `POST /storage/upload/confirm` event, same auth and env vars as `StorageUploadFunction`
  - [ ] `sam validate` passes
  - [ ] Inline upload path is unchanged
  - [ ] Existing unit tests pass (`pytest tests/ -v`)
  - [ ] New unit tests cover: (a) presigned upload returns `confirmation_required`, (b) confirm succeeds when S3 object exists, (c) confirm returns 404 when S3 object missing, (d) re-calling `/storage/upload` with `pending_confirmation` idempotency returns fresh presigned URL

## Task string (optional)

Work only in this repo (mnemospark-backend). Implement a two-phase presigned upload confirmation flow. Phase 1: modify the presigned branch in `lambda_handler()` to defer transaction log and quote deletion, mark idempotency `pending_confirmation`, and include `confirmation_required: true` in the response. Phase 2: add `confirm_upload_handler()` that verifies S3 object exists via `head_object`, writes transaction log, deletes quote, marks idempotency `completed`. Add `UploadConfirmRequest` model and `StorageUploadConfirmFunction` to `template.yaml` at `POST /storage/upload/confirm` with same auth. Handle `pending_confirmation` in idempotency checks (regenerate presigned URL). Use `_log_event()` for structured logging. Do not change inline upload path. Run `sam validate` and `pytest tests/ -v`.
