# Cloud Upload Fix: Order of Operations

This document lists the fix files for the `/mnemospark-cloud upload` flow in the order they must be applied. Each fix is designed as a single agent run targeting one repo.

## Repo Mapping

| Fix ID | Repo | Branch From | Status |
|---|---|---|---|
| fix-01 | `mnemospark` | `main` | **DONE** |
| fix-02 | `mnemospark-backend` | `main` | **DONE** |
| fix-03 | `mnemospark-backend` | `main` or after fix-02 merge | **DONE** |
| fix-04 | `mnemospark-backend` | after fix-03 merge | **DONE** |
| fix-05 | `mnemospark-backend` | `main` or after fix-04 merge | **DONE** |
| fix-06 | `mnemospark` | `main` or after fix-01 merge | Pending |
| fix-07 | `mnemospark-backend` | after fix-04 merge | Pending |
| fix-08 | `mnemospark` | after fix-07 merge (backend deployed) | Pending |

## Execution Order

### Phase 1: Unblock Uploads (Critical / Blocker) -- COMPLETE

These two fixes must be applied first. They can run **in parallel** because they target different repos.

1. **fix-01** -- [Flatten Upload Payload](fix-01-flatten-upload-payload.md) -- **DONE**
   - **Repo:** `mnemospark`
   - **What:** Flattens the nested `payload` object in `forwardStorageUploadToBackend()` so the backend receives `ciphertext` and `wrapped_dek` at the top level.
   - **Depends on:** Nothing.
   - **Unblocks:** All uploads (inline and presigned).

2. **fix-02** -- [Presigned URL Backend](fix-02-presigned-url-backend.md) -- **DONE**
   - **Repo:** `mnemospark-backend`
   - **What:** Adds a presigned URL upload path in the Lambda handler for files > 4.5 MB.
   - **Depends on:** Nothing (the backend API Gateway model is updated independently). However, fix-01 must be deployed for the client to actually send `mode` at the top level.
   - **Unblocks:** Large-file uploads.

### Phase 2: Observability -- COMPLETE

3. **fix-03** -- [Backend Logging](fix-03-backend-logging.md) -- **DONE**
   - **Repo:** `mnemospark-backend`
   - **What:** Adds structured logging to `services/storage-upload/app.py` at all key decision points.
   - **Depends on:** Nothing functionally, but best applied after fix-02 so the logging covers the new presigned URL path.
   - **Unblocks:** fix-04 (which references logger for S3 failure logging).

### Phase 3: Safety and Reliability -- COMPLETE

4. **fix-04** -- [S3 Failure Rollback](fix-04-s3-failure-rollback.md) -- **DONE**
   - **Repo:** `mnemospark-backend`
   - **What:** Wraps S3 upload in its own try/except after payment settlement. Returns 207 on S3 failure with `trans_id` so client can retry without re-paying.
   - **Depends on:** fix-03 (uses logger for error logging).

5. **fix-05** -- [Settlement Mode Onchain Default](fix-05-settlement-mode-onchain-default.md) -- **DONE**
   - **Repo:** `mnemospark-backend`
   - **What:** Changes `MNEMOSPARK_PAYMENT_SETTLEMENT_MODE` default from `mock` to `onchain`. Requires explicit env var override to use mock.
   - **Depends on:** Nothing functionally. Can run at any point after fix-03 (uses logger for mock-mode warning).

### Phase 4: Client Resilience and Presigned Upload Integrity

6. **fix-06** -- [Client Handle 207 S3 Retry](fix-06-client-handle-207-s3-retry.md)
   - **Repo:** `mnemospark`
   - **What:** Detects 207 Multi-Status responses in `requestStorageUploadViaProxy()` (S3 failed after payment). Auto-retries with same Idempotency-Key up to `maxRetries` times. If all retries fail, returns clear error with `trans_id`. Prevents `parseStorageUploadResponse()` from throwing on the 207 body.
   - **Depends on:** fix-04 (backend must return 207 for S3 failures). Can run in parallel with fix-07.

7. **fix-07** -- [Presigned Upload Confirm Backend](fix-07-presigned-upload-confirm-backend.md)
   - **Repo:** `mnemospark-backend`
   - **What:** Adds `POST /storage/upload/confirm` endpoint. Presigned uploads now use a two-phase flow: Phase 1 settles payment and returns presigned URL (marks idempotency `pending_confirmation`, defers transaction log). Phase 2 (confirm) verifies S3 object exists, writes transaction log, completes idempotency.
   - **Depends on:** fix-04 (retryable idempotency infrastructure). Can run in parallel with fix-06.

8. **fix-08** -- [Presigned Upload Confirm Client](fix-08-presigned-upload-confirm-client.md)
   - **Repo:** `mnemospark`
   - **What:** Client and proxy call `POST /storage/upload/confirm` after `uploadPresignedObjectIfNeeded()` succeeds when `confirmation_required` is true. Adds `confirmPresignedUploadViaProxy()`, `forwardUploadConfirmToBackend()`, and proxy route for `/mnemospark/upload/confirm`.
   - **Depends on:** fix-07 (backend confirm endpoint must exist). Must be deployed after fix-07 is merged and deployed.

**fix-06 and fix-07 can run in parallel** (different repos, no code dependency). **fix-08 must wait for fix-07** to be merged and deployed because the backend confirm endpoint must exist before the client calls it.

## Dependency Graph

```
fix-01 (mnemospark)         fix-02 (backend)
        \                       /
         \                     /
          --- Phase 1 done ---           [ALL COMPLETE]
                   |
            fix-03 (backend)
                   |
          --- Phase 2 done ---
                 /   \
   fix-04 (backend)  fix-05 (backend)
                 \   /
          --- Phase 3 done ---
                 /   \
fix-06 (mnemospark)  fix-07 (backend)    [PENDING -- parallel]
                          |
                  fix-08 (mnemospark)     [PENDING -- after fix-07]
                          |
                  --- Phase 4 done ---
```

## Post-Merge Verification

After all eight PRs are merged and deployed:

1. Deploy the updated `mnemospark-backend` stack with `PaymentSettlementMode=onchain` (now the default).
2. Run a test upload with a small file (< 4.5 MB) to verify inline path end-to-end.
3. Run a test upload with a large file (> 4.5 MB) to verify presigned URL path with confirmation step.
4. Verify CloudWatch Logs contain structured log entries at each decision point.
5. Verify that mock mode requires explicit `MNEMOSPARK_PAYMENT_SETTLEMENT_MODE=mock` override.
6. Test S3 failure recovery: simulate an S3 failure for inline upload, verify the client auto-retries and the user sees a clear message with `trans_id` if retries are exhausted.
7. Test presigned confirmation: verify that the transaction log is NOT written until `/storage/upload/confirm` is called and the S3 object is verified.
