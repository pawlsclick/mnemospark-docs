# Cursor Dev: Handle S3 Upload Failure After Payment Settlement

**ID:** fix-04  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. This repo is a serverless AWS Lambda backend (Python 3.13) using AWS SAM. The storage upload Lambda lives at `services/storage-upload/app.py`. Do **not** clone, or require access to any other repository; all code and references are in this file References.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Fix the **payment-settled-but-file-not-stored** risk in the `/storage/upload` Lambda handler. Depends on fix-03 (logging is available for observability of this new error path).

Currently in `lambda_handler()` (`app.py` lines 1135-1152), payment is settled first (line 1135), then S3 upload happens (line 1146). If S3 upload fails after payment succeeds:

- The generic `except Exception` handler (line 1227) releases the idempotency lock.
- On-chain payment is already settled -- the USDC `transferWithAuthorization` nonce is consumed.
- A retry with the same payment signature fails (nonce already used).
- The user has been charged but their file was not stored.

**Changes required:**

1. **Wrap the S3 upload in its own try/except** inside `lambda_handler()`, after the payment settlement block (after line 1144). The structure should be:

   ```python
   payment_result = verify_and_settle_payment(...)

   try:
       bucket_name = _upload_ciphertext_to_s3(...)
   except Exception as s3_exc:
       # Payment succeeded but S3 failed -- do NOT release idempotency lock.
       # Log the failure for operational alerting.
       logger.error(json.dumps({
           "event": "s3_upload_failed_after_payment",
           "quote_id": request.quote_id,
           "trans_id": payment_result.trans_id,
           "wallet_address": request.wallet_address,
           "object_key": request.object_key,
           "error": str(s3_exc),
       }))
       # Return 207 (Multi-Status) with trans_id so client knows payment succeeded
       # but can retry the S3 upload.
       response_body = {
           "quote_id": request.quote_id,
           "addr": request.wallet_address,
           "addr_hash": _wallet_hash(request.wallet_address),
           "trans_id": payment_result.trans_id,
           "storage_price": float(quote_context.storage_price),
           "object_id": request.object_id,
           "object_key": request.object_key,
           "provider": quote_context.provider,
           "bucket_name": _bucket_name(request.wallet_address),
           "location": quote_context.location,
           "upload_failed": True,
           "error": "S3 upload failed after payment settlement. Retry the upload.",
       }
       payment_response_header = _encode_json_base64({
           "trans_id": payment_result.trans_id,
           "network": payment_result.network,
           "asset": payment_result.asset,
           "amount": str(payment_result.amount),
       })
       # Do NOT release idempotency lock -- keep it in_progress so
       # a retry with the same idempotency key re-enters the handler
       # and can re-attempt the S3 upload.
       return _response(
           207,
           response_body,
           headers=_payment_response_headers(payment_response_header),
       )
   ```

2. **Do NOT release the idempotency lock** when S3 fails after payment. By keeping the lock in `in_progress` state, a retry with the same `Idempotency-Key` will not be treated as a conflict. The TTL on the idempotency table (`IDEMPOTENCY_TTL_SECONDS = 24 * 60 * 60`) provides an automatic expiry for stuck locks.

3. **Update the general `except Exception` handler** (line 1227) to distinguish between "payment settled but S3 failed" (handled by the new inner try/except) and other unhandled errors. After this change, the outer `except Exception` should only fire for errors that occur BEFORE or AFTER the S3 upload block (e.g., transaction log write failures), not for S3 failures themselves.

4. **Add unit tests** for the new error path:
   - Mock `_upload_ciphertext_to_s3` to raise `ClientError` or `Exception` after `verify_and_settle_payment` succeeds.
   - Assert the response is status 207 with `upload_failed: True` and `trans_id` present.
   - Assert the idempotency lock is NOT released (verify `_release_idempotency_lock` was not called for this case).

## References

- `services/storage-upload/app.py` -- `lambda_handler()` (line 1086), `verify_and_settle_payment()` (line 1135), `_upload_ciphertext_to_s3()` (line 1146), `_release_idempotency_lock()`, `_bucket_name()`, `_wallet_hash()`, `_encode_json_base64()`, `_response()` (line 177), `_payment_response_headers()`, error handlers (lines 1203-1230), `IDEMPOTENCY_TTL_SECONDS` (line 39)
- `tests/unit/test_storage_upload.py` -- existing unit tests with mocked DynamoDB and S3
- [cloud-upload-process-flow.md](../../meta_docs/cloud-upload-process-flow.md) section 8.4

## Agent

- **Install (idempotent):** `source /workspace/.venv/bin/activate && pip install -r services/storage-upload/requirements.txt`
- **Start (if needed):** None.
- **Secrets:** None required for unit tests (mocked).
- **Acceptance criteria (checkboxes):**
  - [ ] S3 upload is wrapped in its own try/except inside `lambda_handler()`, after payment settlement
  - [ ] On S3 failure after payment, handler returns 207 with `upload_failed: True` and `trans_id`
  - [ ] On S3 failure after payment, the idempotency lock is NOT released (kept in `in_progress`)
  - [ ] The S3 failure is logged at ERROR level with `quote_id`, `trans_id`, `wallet_address`, and error details
  - [ ] The 207 response includes `PAYMENT-RESPONSE` headers so the client can verify payment succeeded
  - [ ] The outer `except Exception` handler (line 1227) still handles non-S3 failures correctly
  - [ ] Unit tests mock S3 failure after payment success and assert 207 response
  - [ ] Lint passes: `ruff check services/storage-upload/`
  - [ ] Tests pass: `pytest tests/ -v`
  - [ ] The agent creates a new branch, commits, and opens a PR

## Task string (optional)

Work only in this repo (mnemospark-backend). In `services/storage-upload/app.py` `lambda_handler()`, wrap the `_upload_ciphertext_to_s3()` call in its own try/except after `verify_and_settle_payment()`. On S3 failure: log the error at ERROR level, return 207 with `upload_failed: True` and `trans_id` and `PAYMENT-RESPONSE` headers, and do NOT release the idempotency lock. Add unit tests mocking S3 failure after payment success. Run `ruff check services/storage-upload/` and `pytest tests/ -v`. Create a new branch and PR.
