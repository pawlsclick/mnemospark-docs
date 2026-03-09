# Cursor Dev: Client Handle 207 (S3 Failure After Payment) With Auto-Retry

**ID:** fix-06
**Repo:** mnemospark

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark. This is the OpenClaw plugin client and local proxy. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** Not applicable -- this fix is client-side only.

## Scope

When the backend returns HTTP **207 Multi-Status** (S3 upload failed after payment was settled), the client currently passes the response through `parseStorageUploadResponse()` which throws `"Upload response is missing required fields"` because the 207 body is missing fields like `object_key`, `provider`, `bucket_name`, `location`. The user sees a cryptic error, and the retryable idempotency opportunity on the backend is wasted.

This fix adds 207 detection and automatic retry logic so the client:

1. Detects the 207 status or the `upload_failed: true` field in the response body before calling `parseStorageUploadResponse()`.
2. Automatically retries the upload request with the **same `Idempotency-Key`** (the backend will resume from the `retryable` idempotency state, skipping payment re-verification).
3. If the retry succeeds (200), continues normally through the existing success path.
4. If the retry also returns 207 or fails, returns a clear user-facing error message that includes the `trans_id` so the user can contact support, and does **not** call `parseStorageUploadResponse()` on the 207 body.

### Changes required

**`src/cloud-price-storage.ts`**

1. **`requestStorageUploadViaProxy()`** (line 345): Add auto-retry logic for 207 responses inside the function. Keep the return type as `StorageUploadResponse` (no API contract changes). After getting the response at line 367, before the `!response.ok` check, add a check for `response.status === 207`:

   - Parse the JSON body and check for `upload_failed === true`.
   - Extract `trans_id` from the parsed body.
   - Re-issue the same `POST` to `${baseUrl}${UPLOAD_PROXY_PATH}` with the same headers (including the same `Idempotency-Key`), up to `maxRetries` times (default `2`).
   - Between retries, wait 1 second (`await new Promise(r => setTimeout(r, 1000))`).
   - If a retry returns 200, call `parseStorageUploadResponse()` on that response and return normally.
   - If all retries return 207 or fail, throw an `Error` with the message: `"Payment confirmed (trans_id: ${transId}) but file storage failed after ${maxRetries} retries. Contact support with your trans_id."`.
   - Do NOT call `parseStorageUploadResponse()` for any 207 response body.

**`src/cloud-price-storage.ts` -- type updates**

2. Add `maxRetries?: number` to the `ProxyUploadOptions` type (around line 83).

**`src/cloud-command.ts`**

3. In the `catch (error)` block at line 1380, add special handling for the payment-confirmed-but-storage-failed case. `extractUploadErrorMessage(error)` already returns the error message, so this should work automatically. Verify the error message includes the `trans_id` and is user-friendly.

No changes needed to `src/proxy.ts` -- the proxy already relays the 207 status and body correctly (line 441).

## References

- `src/cloud-price-storage.ts` lines 56-69: `StorageUploadResponse` type definition
- `src/cloud-price-storage.ts` lines 271-313: `parseStorageUploadResponse()` -- requires `quoteId`, `addr`, `objectId`, `objectKey`, `provider`, `bucketName`, `location` to be non-empty; will throw on 207 body
- `src/cloud-price-storage.ts` lines 345-379: `requestStorageUploadViaProxy()` -- `!response.ok` check at line 368 passes 207 (it is in the 200-299 range); then calls `parseStorageUploadResponse()` which throws
- `src/cloud-price-storage.ts` lines 73-97: `ProxyUploadOptions` type (add `maxRetries` here)
- `src/cloud-command.ts` lines 1266-1386: upload handler block that calls `requestStorageUpload()` and catches errors at line 1380
- `src/cloud-command.ts` lines 1108-1141: `extractUploadErrorMessage()` -- extracts message from Error, including JSON payloads
- `src/proxy.ts` lines 417-442: proxy relays `backendResponse.status` directly to client at line 441 (207 passes through)
- Backend 207 response body shape (from `mnemospark-backend/services/storage-upload/app.py` lines 1500-1513):
  ```json
  {
    "quote_id": "...",
    "addr": "0x...",
    "addr_hash": "...",
    "trans_id": "0x...",
    "storage_price": 1.25,
    "object_id": "...",
    "object_key": "...",
    "provider": "aws",
    "bucket_name": "mnemospark-...",
    "location": "us-east-1",
    "upload_failed": true,
    "error": "S3 upload failed after payment settlement. Retry the upload."
  }
  ```
- Backend retryable idempotency: on retry with the same `Idempotency-Key`, the backend restores cached payment result and re-attempts S3 upload without re-charging

## Agent

- **Install (idempotent):** `npm install`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] `requestStorageUploadViaProxy()` detects `response.status === 207` before calling `parseStorageUploadResponse()`
  - [ ] On 207, the function automatically retries the POST with the same headers (including `Idempotency-Key`) up to `maxRetries` times (default 2)
  - [ ] Between retries, waits at least 1 second
  - [ ] If a retry returns 200, `parseStorageUploadResponse()` is called on that response and the function returns normally
  - [ ] If all retries return 207 or fail, an Error is thrown with a message containing the `trans_id` from the 207 body
  - [ ] `ProxyUploadOptions` type has a new optional `maxRetries` field
  - [ ] `parseStorageUploadResponse()` is never called on a 207 response body
  - [ ] Existing unit tests still pass (`npm test`)
  - [ ] New unit tests cover: (a) 207 -> retry -> 200 success path, (b) 207 -> retry -> 207 -> exhausted retries error path, (c) 207 body without `upload_failed` treated as normal 2xx

## Task string (optional)

Work only in this repo (mnemospark). Implement 207 Multi-Status handling in `requestStorageUploadViaProxy()` in `src/cloud-price-storage.ts`. When the proxy returns HTTP 207 with `upload_failed: true` in the JSON body, automatically retry the upload (same Idempotency-Key, same headers) up to `maxRetries` (default 2) with 1-second delay between attempts. If a retry returns 200, parse and return normally. If all retries fail, throw an Error with the trans_id from the 207 body. Add `maxRetries` to `ProxyUploadOptions`. Never call `parseStorageUploadResponse()` on a 207 body. Add unit tests for the retry and exhaustion paths. Run `npm test` to verify.
