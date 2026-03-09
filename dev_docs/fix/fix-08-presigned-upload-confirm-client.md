# Cursor Dev: Presigned Upload Confirmation Call (Client)

**ID:** fix-08
**Repo:** mnemospark

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark. This is the OpenClaw plugin client and local proxy. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** Not applicable -- this fix is client-side only.

## Scope

After fix-07, the backend returns `"confirmation_required": true` in presigned upload responses. The backend no longer writes the transaction log or marks the upload complete until the client calls `POST /storage/upload/confirm`. This fix adds the confirmation step on the client and proxy side.

Depends on fix-07 (presigned upload confirm backend endpoint).

### Changes required

**`src/cloud-price-storage.ts`**

1. **Add `confirmation_required` to `StorageUploadResponse` type** (line 56): Add `confirmation_required?: boolean` to the type definition.

2. **Update `parseStorageUploadResponse()`** (line 271): Read `record.confirmation_required` as an optional boolean field and include it in the returned object.

3. **New function `confirmPresignedUploadViaProxy()`**: Similar to `requestStorageUploadViaProxy()` but calls the confirm proxy path. Signature:
   ```typescript
   export async function confirmPresignedUploadViaProxy(
     confirmRequest: PresignedUploadConfirmRequest,
     options: ProxyUploadOptions,
   ): Promise<StorageUploadResponse>
   ```
   Where `PresignedUploadConfirmRequest` is a new exported type:
   ```typescript
   export type PresignedUploadConfirmRequest = {
     wallet_address: string;
     object_key: string;
     idempotency_key: string;
     quote_id: string;
   };
   ```
   The function POSTs to `${baseUrl}/mnemospark/upload/confirm` with the JSON body and returns the parsed `StorageUploadResponse`.

4. **New constant `UPLOAD_CONFIRM_PROXY_PATH`**: Set to `"/mnemospark/upload/confirm"`.

5. **New function `forwardUploadConfirmToBackend()`**: Similar to `forwardStorageUploadToBackend()` but for the confirm endpoint. POSTs to `${backendBaseUrl}/storage/upload/confirm` with the same headers (`X-Wallet-Signature`, `Idempotency-Key`). Returns `BackendUploadForwardResult`.

**`src/proxy.ts`**

6. **New route handler for `POST /mnemospark/upload/confirm`**: Add a new `if` block after the existing upload route (after line 449). It should:
   - Read the JSON body and parse the confirm request fields (`wallet_address`, `object_key`, `idempotency_key`, `quote_id`).
   - Enforce wallet ownership (same as upload route).
   - Create the backend wallet signature (same pattern as upload route).
   - Call `forwardUploadConfirmToBackend()`.
   - Relay the backend response status and body.
   - Handle auth failures and proxy errors the same way as the upload route.

7. **Import** `UPLOAD_CONFIRM_PROXY_PATH` and `forwardUploadConfirmToBackend` from `cloud-price-storage.js`.

**`src/cloud-command.ts`**

8. **After `uploadPresignedObjectIfNeeded()` succeeds** (line 1356-1361), check `uploadResponse.confirmation_required`. If true:
   - Call `confirmPresignedUploadViaProxy()` with `{ wallet_address, object_key: uploadResponse.object_key, idempotency_key, quote_id }`.
   - Use the confirm response (which has the finalized transaction log data) for subsequent steps (`appendStorageUploadLog`, `createStoragePaymentCronJob`, etc.) instead of the original `uploadResponse`.
   - If the confirm call fails, return a clear error message that includes the `trans_id` so the user knows payment was collected.

9. **Import** `confirmPresignedUploadViaProxy` from `cloud-price-storage.js`.

### Notes

- The inline upload path is **unchanged** -- it does not return `confirmation_required` and skips the confirm step.
- The `idempotencyKey` is already generated at line 1338 in `cloud-command.ts` and used for the initial upload request. The same key should be passed to the confirm request.
- The x402 payment fetch wrapper is NOT needed for the confirm call since payment was already settled during the initial upload. Use the regular `fetchImpl` (or the proxy forwarding function which handles headers).

## References

- `src/cloud-price-storage.ts` lines 56-69: `StorageUploadResponse` type -- add `confirmation_required?: boolean`
- `src/cloud-price-storage.ts` lines 271-313: `parseStorageUploadResponse()` -- add `confirmation_required` field parsing
- `src/cloud-price-storage.ts` lines 345-379: `requestStorageUploadViaProxy()` -- model for `confirmPresignedUploadViaProxy()`
- `src/cloud-price-storage.ts` lines 416-516: `forwardStorageUploadToBackend()` -- model for `forwardUploadConfirmToBackend()`
- `src/cloud-price-storage.ts` lines 73-97: `ProxyUploadOptions` type -- reuse for confirm options
- `src/cloud-price-storage.ts` lines 107-113: `BackendUploadForwardResult` type -- reuse for confirm forward result
- `src/proxy.ts` lines 342-449: existing upload route handler -- model for confirm route
- `src/proxy.ts` lines 417-442: `forwardStorageUploadToBackend()` call and response relay -- model for confirm forwarding
- `src/cloud-command.ts` lines 1338: `idempotencyKey` generation -- same key used for confirm
- `src/cloud-command.ts` lines 1340-1354: `requestStorageUpload()` call -- the `uploadResponse` may have `confirmation_required`
- `src/cloud-command.ts` lines 1356-1361: `uploadPresignedObjectIfNeeded()` -- confirm should be called after this succeeds
- `src/cloud-command.ts` lines 1362-1378: post-upload steps (log, cron, cleanup, message) -- should use confirm response if presigned
- Backend confirm endpoint shape (from fix-07):
  - Path: `POST /storage/upload/confirm`
  - Auth: `WalletRequestAuthorizer` (same `X-Wallet-Signature` header)
  - Body: `{ "wallet_address": "0x...", "object_key": "...", "idempotency_key": "...", "quote_id": "..." }`
  - Returns 200 with same `StorageUploadResponse` shape (without `upload_url`)
  - Returns 404 if S3 object not found

## Agent

- **Install (idempotent):** `npm install`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] `StorageUploadResponse` type has `confirmation_required?: boolean`
  - [ ] `parseStorageUploadResponse()` reads and returns `confirmation_required`
  - [ ] New type `PresignedUploadConfirmRequest` exported with fields: `wallet_address`, `object_key`, `idempotency_key`, `quote_id`
  - [ ] New constant `UPLOAD_CONFIRM_PROXY_PATH` set to `"/mnemospark/upload/confirm"`
  - [ ] New function `confirmPresignedUploadViaProxy()` POSTs to confirm proxy path and returns parsed `StorageUploadResponse`
  - [ ] New function `forwardUploadConfirmToBackend()` POSTs to `${backendBaseUrl}/storage/upload/confirm` with wallet signature and idempotency headers
  - [ ] New proxy route for `POST /mnemospark/upload/confirm` with wallet ownership check, signature, and backend forwarding
  - [ ] Upload handler in `cloud-command.ts` checks `confirmation_required` after `uploadPresignedObjectIfNeeded()` and calls `confirmPresignedUploadViaProxy()`
  - [ ] Confirm response is used for `appendStorageUploadLog`, `createStoragePaymentCronJob`, and user message when `confirmation_required` is true
  - [ ] On confirm failure, error message includes `trans_id`
  - [ ] Inline uploads (no `confirmation_required`) continue to work unchanged
  - [ ] Existing unit tests pass (`npm test`)
  - [ ] New unit tests cover: (a) presigned flow calls confirm after S3 PUT, (b) inline flow skips confirm, (c) confirm failure returns descriptive error with trans_id

## Task string (optional)

Work only in this repo (mnemospark). After fix-07, presigned upload responses include `confirmation_required: true`. Add client and proxy support: (1) add `confirmation_required` to `StorageUploadResponse` and its parser, (2) create `confirmPresignedUploadViaProxy()` and `forwardUploadConfirmToBackend()` in `src/cloud-price-storage.ts`, (3) add proxy route `POST /mnemospark/upload/confirm` in `src/proxy.ts` with wallet auth and backend forwarding, (4) in `src/cloud-command.ts` upload handler, call confirm after `uploadPresignedObjectIfNeeded()` when `confirmation_required` is true, use confirm response for logging/cron. Run `npm test`.
