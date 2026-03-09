# Cloud Upload Fix: Order of Operations

This document lists the fix files for the `/mnemospark-cloud upload` flow in the order they must be applied. Each fix is designed as a single agent run targeting one repo.

## Repo Mapping

| Fix ID | Repo | Branch From |
|---|---|---|
| fix-01 | `mnemospark` | `main` |
| fix-02 | `mnemospark-backend` | `main` |
| fix-03 | `mnemospark-backend` | `main` or after fix-02 merge |
| fix-04 | `mnemospark-backend` | after fix-03 merge |
| fix-05 | `mnemospark-backend` | `main` or after fix-04 merge |

## Execution Order

### Phase 1: Unblock Uploads (Critical / Blocker)

These two fixes must be applied first. They can run **in parallel** because they target different repos.

1. **fix-01** -- [Flatten Upload Payload](fix-01-flatten-upload-payload.md)
   - **Repo:** `mnemospark`
   - **What:** Flattens the nested `payload` object in `forwardStorageUploadToBackend()` so the backend receives `ciphertext` and `wrapped_dek` at the top level.
   - **Depends on:** Nothing.
   - **Unblocks:** All uploads (inline and presigned).

2. **fix-02** -- [Presigned URL Backend](fix-02-presigned-url-backend.md)
   - **Repo:** `mnemospark-backend`
   - **What:** Adds a presigned URL upload path in the Lambda handler for files > 4.5 MB.
   - **Depends on:** Nothing (the backend API Gateway model is updated independently). However, fix-01 must be deployed for the client to actually send `mode` at the top level.
   - **Unblocks:** Large-file uploads.

**Merge both PRs before proceeding to Phase 2.**

### Phase 2: Observability

3. **fix-03** -- [Backend Logging](fix-03-backend-logging.md)
   - **Repo:** `mnemospark-backend`
   - **What:** Adds structured logging to `services/storage-upload/app.py` at all key decision points.
   - **Depends on:** Nothing functionally, but best applied after fix-02 so the logging covers the new presigned URL path.
   - **Unblocks:** fix-04 (which references logger for S3 failure logging).

**Merge this PR before proceeding to Phase 3.**

### Phase 3: Safety and Reliability

These two can run **in parallel** after fix-03 is merged.

4. **fix-04** -- [S3 Failure Rollback](fix-04-s3-failure-rollback.md)
   - **Repo:** `mnemospark-backend`
   - **What:** Wraps S3 upload in its own try/except after payment settlement. Returns 207 on S3 failure with `trans_id` so client can retry without re-paying.
   - **Depends on:** fix-03 (uses logger for error logging).

5. **fix-05** -- [Settlement Mode Onchain Default](fix-05-settlement-mode-onchain-default.md)
   - **Repo:** `mnemospark-backend`
   - **What:** Changes `MNEMOSPARK_PAYMENT_SETTLEMENT_MODE` default from `mock` to `onchain`. Requires explicit env var override to use mock.
   - **Depends on:** Nothing functionally. Can run at any point after fix-03 (uses logger for mock-mode warning).

## Dependency Graph

```
fix-01 (mnemospark)         fix-02 (backend)
        \                       /
         \                     /
          --- Phase 1 done ---
                   |
            fix-03 (backend)
                   |
          --- Phase 2 done ---
                 /   \
   fix-04 (backend)  fix-05 (backend)
```

## Post-Merge Verification

After all five PRs are merged and deployed:

1. Deploy the updated `mnemospark-backend` stack with `PaymentSettlementMode=onchain` (now the default).
2. Run a test upload with a small file (< 4.5 MB) to verify inline path end-to-end.
3. Run a test upload with a large file (> 4.5 MB) to verify presigned URL path.
4. Verify CloudWatch Logs contain structured log entries at each decision point.
5. Verify that mock mode requires explicit `MNEMOSPARK_PAYMENT_SETTLEMENT_MODE=mock` override.
