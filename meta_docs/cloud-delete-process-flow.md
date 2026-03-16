# Cloud Delete Process Flow

**Date:** 2026-03-16  
**Revision:** rev 1  
**Milestone:** e2e-staging-2026-03-16 (mnemospark & mnemospark-backend)  
**Repos / components:** mnemospark (client, proxy), mnemospark-backend (storage-delete, wallet-authorizer)

End-to-end documentation of the `/mnemospark-cloud delete` command, covering the client, local proxy, and AWS backend.

**Goal**: Delete the object from S3 storage and remove the local system cron job that sends payment for the storage object. The backend deletes the object (and the bucket if empty); the **client** then looks up the payment cron entry by object key in `object.log` and removes that job’s entry from the tracking file `~/.openclaw/mnemospark/crontab.txt`. The code does **not** modify the user’s system crontab (e.g. via `crontab -r` or `crontab -`); it only updates the local tracking file.

---

## 1. Command Overview

```
/mnemospark-cloud delete --wallet-address <addr> --object-key <object-key>
```

### Required Parameters

| Flag | Description |
|------|-------------|
| `--wallet-address` | EVM wallet address (0x-prefixed). Must match the proxy’s wallet; the backend deletes from that wallet’s S3 bucket. |
| `--object-key` | The S3 object key (same as used for upload/ls/download). Must be a **single path segment** (no `/` or `\`) per backend validation. |

Optional: `--location` or `--region` (AWS region for the S3 bucket).

### Prerequisites

1. The object must exist in the wallet’s S3 bucket (backend returns 404 if bucket or object not found).
2. Local proxy running on `127.0.0.1:7120` with a wallet key (proxy signs the request to the backend).
3. `MNEMOSPARK_BACKEND_API_BASE_URL` set so the proxy can forward to the backend.
4. For cron cleanup: `object.log` and optionally `crontab.txt` under the client’s home (or `objectLogHomeDir`). Cron removal is best-effort after a successful cloud delete.

---

## 2. Step-by-Step Flow

### 2.1 Client (mnemospark)

**Entry point**: Cloud command handler in `createCloudCommand()` in `src/cloud-command.ts`. For `delete`, the handler first calls the proxy to delete the object in S3; on success it then looks up and removes the payment cron entry from the local tracking file.

#### Step 1 — Argument Parsing

`parseCloudArgs(ctx.args)` (around line 341):

- Expects the first token to be `delete` and the rest to be `--key value` pairs.
- `parseStorageObjectRequest({ "wallet-address", "object-key", location/region })` validates: `wallet_address` and `object_key` required; optional `location` / `region`.
- If valid → `{ mode: "delete", storageObjectRequest }`. If invalid → `{ mode: "delete-invalid" }`; handler returns `"Cannot delete file: required arguments are --wallet-address, --object-key."` with `isError: true`.

#### Step 2 — Request to Proxy

`requestStorageDelete(parsed.storageObjectRequest, options.proxyStorageOptions)` (default: `requestStorageDeleteViaProxy` in `src/cloud-storage.ts`):

- **URL**: `POST {proxyBaseUrl}/mnemospark/storage/delete` (default `http://127.0.0.1:7120/mnemospark/storage/delete`).
- **Headers**: `Content-Type: application/json`.
- **Body**: JSON `{ wallet_address, object_key, location? }`.

#### Step 3 — Response Handling

- Proxy forwards to the backend and returns the backend’s status and body. On **200**, backend body is JSON `{ success, key, bucket, bucket_deleted }`.
- `parseStorageDeleteResponse` expects `key`, `bucket`; `success` defaults to true if absent. If `deleteResult.success === false` or proxy returns non-OK, the handler throws and returns `{ text: "Cannot delete file", isError: true }` (no backend/proxy detail in the message).

#### Step 4 — Cron Lookup and Removal (after successful cloud delete)

- **Only after** cloud delete succeeds, the client does best-effort cron cleanup:
  - `objectLogHomeDir` = `options.objectLogHomeDir ?? options.backupOptions?.homeDir` (defaults to process `homedir()`).
  - `findLoggedStoragePaymentCronByObjectKey(parsed.storageObjectRequest.object_key, objectLogHomeDir)`:
    - Reads `~/.openclaw/mnemospark/object.log` (or `{objectLogHomeDir}/.openclaw/mnemospark/object.log`).
    - Parses lines from the end; looks for a row with prefix `storage-payment-cron,` and `objectKey` matching the delete request. Returns `{ cronId, objectKey, ... }` or `null`.
  - If a cron entry is found: `removeStoragePaymentCronJob(cronEntry.cronId, objectLogHomeDir)`:
    - Reads `~/.openclaw/mnemospark/crontab.txt` (or `{objectLogHomeDir}/.openclaw/mnemospark/crontab.txt`).
    - Removes the line whose JSON parses to a job with matching `cronId`; rewrites the file with the remaining lines. Returns `true` if a line was removed, `false` if not found or file missing.
  - If `object.log` or `crontab.txt` is missing or cron lookup/removal throws, the handler **ignores** the error and still reports success (cloud delete already succeeded).

#### Step 5 — Success Message

- Handler returns `formatStorageDeleteUserMessage(objectKey, cronEntry?.cronId ?? null, cronDeleted)`:
  - If cron was found and removed: `"File \`<object_key>\` has been deleted from the cloud and the cron job \`<cronId>\` has been deleted from your system."`
  - If cron was found but not in file: `"File \`<object_key>\` has been deleted from the cloud and the cron job \`<cronId>\` was not found in your system."`
  - If no cron found: `"File \`<object_key>\` has been deleted from the cloud and no matching cron job was found in your system."`
  - All variants append `"Thank you for using mnemospark!"`.

---

### 2.2 Local Proxy (mnemospark)

**Entry point**: `src/proxy.ts`, route for `POST` and path matching `STORAGE_DELETE_PROXY_PATH` (`/mnemospark/storage/delete`) around line 613.

#### Step 1 — Read and Parse Body

- `readProxyJsonBody(req)` parses JSON. On failure, proxy responds **400** with `"Invalid JSON body for /mnemospark cloud delete"`.
- `parseStorageObjectRequest(payload)` validates `wallet_address` and `object_key`. If `null`, proxy responds **400** with `"Missing required fields: wallet_address, object_key"`.

#### Step 2 — Wallet Match and Signature

- Compares request `wallet_address` to proxy wallet (403 if mismatch). Creates `X-Wallet-Signature` for the backend (400 if no wallet key, via `createWalletRequiredBody()`).

#### Step 3 — Forward to Backend

- `forwardStorageDeleteToBackend(requestPayload, { backendBaseUrl, walletSignature })`:
  - **URL**: `POST {MNEMOSPARK_BACKEND_API_BASE_URL}/storage/delete`.
  - **Headers**: `Content-Type: application/json`, `X-Wallet-Signature`.
  - **Body**: Same JSON (`wallet_address`, `object_key`, `location`).
- Backend returns **200** with `{ success, key, bucket, bucket_deleted }` or an error status. Proxy does **not** modify the response; it forwards status and body to the client.

#### Step 4 — Auth and Error Handling

- If `normalizeBackendAuthFailure(backendResponse)` indicates an auth/payment failure, proxy responds with that status and body and returns.
- Otherwise: `res.writeHead(backendResponse.status, ...)` and `res.end(backendResponse.bodyText)` (forwards backend response as-is).
- On any exception during the handler, proxy responds **502** with `"Failed to forward /mnemospark cloud delete: <message>"`.

---

### 2.3 Backend (mnemospark-backend)

**Entry point**: Storage delete Lambda, handler in `services/storage-delete/app.py`. **Route**: `POST` or `DELETE` `/storage/delete`. The client path uses POST with a JSON body.

#### Step 1 — Input Parsing

`parse_input(event)` (line 211):

- `_collect_request_params(event)` merges query and body. Requires: `wallet_address` (0x, 20-byte hex), `object_key` (single path segment). Optional: `location`/`region` (default `AWS_REGION` or `us-east-1`).
- `_validate_object_key(object_key)` disallows empty, `/`, `\`, `.`, `..`. On failure, **400**.

#### Step 2 — Authorizer

- `_require_authorized_wallet(event, request.wallet_address)`: wallet required; if missing or not matching, **403 forbidden**.

#### Step 3 — Bucket and Object Existence

- **Bucket**: `_bucket_name(wallet_address)` → `mnemospark-{wallet_hash}`.
- `_require_bucket_exists(s3_client, bucket)`: `head_bucket`; if 404/NotFound/NoSuchBucket → **404** `bucket_not_found`.
- `_require_object_exists(s3_client, bucket, request.object_key)`: `head_object`; if 404/NotFound/NoSuchKey → **404** `object_not_found`.

#### Step 4 — Delete Object and Optionally Bucket

- `delete_object(request, s3_client)`:
  - `s3_client.delete_object(Bucket=bucket, Key=request.object_key)`.
  - `s3_client.list_objects_v2(Bucket=bucket, MaxKeys=1)`. If the bucket is empty (`KeyCount === 0` or no `Contents`), `s3_client.delete_bucket(Bucket=bucket)` (ignores `BucketNotEmpty`); sets `bucket_deleted = True` when delete succeeds.
- Returns **200** with `{ "success": true, "key": request.object_key, "bucket": bucket, "bucket_deleted": bucket_deleted }`.

---

## 3. Files Used Across the Path

### Client and Proxy (mnemospark repo)

| File | Role |
|------|------|
| `src/index.ts` | Registers the `/mnemospark-cloud` command. |
| `src/cloud-command.ts` | Parses `delete` args; calls `requestStorageDelete`; on success runs `findLoggedStoragePaymentCronByObjectKey` and `removeStoragePaymentCronJob`; formats `formatStorageDeleteUserMessage`. Defines `OBJECT_LOG_SUBPATH`, `CRON_TABLE_SUBPATH`, `resolveObjectLogPath`, `resolveCronTablePath`, cron parsing and file read/write. |
| `src/cloud-storage.ts` | `StorageObjectRequest`, `StorageDeleteResponse`; `parseStorageObjectRequest`, `parseStorageDeleteResponse`; `requestStorageDeleteViaProxy`; `forwardStorageDeleteToBackend` (forwards to `/storage/delete`); `STORAGE_DELETE_PROXY_PATH`. |
| `src/proxy.ts` | POST `/mnemospark/storage/delete`: read body, parse, wallet match, signature, forward to backend; forward backend status/body to client; 502 on exception. |
| `src/config.ts` | `PROXY_PORT`. |
| `src/mnemospark-request-sign.ts` | Proxy creates `X-Wallet-Signature` for backend. |
| `src/cloud-utils.ts` | `asRecord`, `asNonEmptyString`, `asBooleanOrDefault`, etc. |

### Backend (mnemospark-backend repo)

| File | Role |
|------|------|
| `services/storage-delete/app.py` | Lambda: `parse_input`, `_require_authorized_wallet`, `_bucket_name`, `_require_bucket_exists`, `_require_object_exists`, `delete_object` (delete_object + optional delete_bucket); returns 200 with `success`, `key`, `bucket`, `bucket_deleted`. |
| `template.yaml` | Storage delete function, POST/DELETE `/storage/delete`, Auth. |
| `services/wallet-authorizer/app.py` | Authorizer for `/storage/delete` (wallet required). |

### Local Filesystem (client host)

| Path | Role |
|------|------|
| `~/.openclaw/mnemospark/object.log` | Read by `findLoggedStoragePaymentCronByObjectKey` to find the cron row for the object key (storage-payment-cron lines). |
| `~/.openclaw/mnemospark/crontab.txt` | Read and rewritten by `removeStoragePaymentCronJob` to remove the line for the matching `cronId`. |

---

## 4. Logging

### Client (mnemospark)

- The delete handler does not call `api.logger`. On failure it returns "Cannot delete file" with no proxy/backend detail. Cron lookup/removal errors are swallowed.

### Proxy (mnemospark)

- No dedicated log for delete success or failure. Generic stream error logging only. 502 response body includes the exception message.

### Backend (mnemospark-backend)

- `services/storage-delete/app.py` has no structured logging. Exceptions are mapped to 4xx/5xx responses; Lambda stdout goes to CloudWatch.

---

## 5. Success

### What the user sees

- A message that the file was deleted from the cloud and either: (1) the cron job was deleted from the system, (2) the cron job was not found in the system, or (3) no matching cron job was found. Plus "Thank you for using mnemospark!".

### What happens in S3

- The object is removed from the wallet’s bucket (`mnemospark-{wallet_hash}`). If the bucket becomes empty, the bucket is deleted.

### What happens locally (cron)

- The client removes **one line** from the file `~/.openclaw/mnemospark/crontab.txt` that corresponds to the cron job for that object key (found via `object.log`). The **system** crontab (e.g. `crontab -l`) is **not** modified by this code; only the tracking file is updated.

---

## 6. Failure Scenarios

### Client-side

| Condition | Result | `isError` |
|-----------|--------|-----------|
| Missing/invalid args | "Cannot delete file: required arguments are ..." | true |
| Proxy non-OK or parse error | "Cannot delete file" (no detail) | true |
| Response has `success === false` | "Cannot delete file" | true |
| Cron lookup/removal throws | Ignored; success message still returned (cloud delete already succeeded). | false |

### Proxy-side

| Status | Condition |
|--------|-----------|
| 400 | Invalid JSON; missing fields; or wallet signature could not be created. |
| 403 | Request wallet does not match proxy wallet. |
| 502 | Backend URL not set, no wallet key, or exception during forward. |
| 4xx/5xx from backend | Proxy forwards the same status and body to the client. |

### Backend-side

| Status | Condition |
|--------|-----------|
| 400 | Bad request (e.g. invalid wallet_address or object_key). |
| 403 | Forbidden (authorizer wallet missing or mismatch). |
| 404 | Bucket not found or object not found. |
| 500 | Unhandled exception. |

---

## 7. What the Command Returns

- **Success**: `{ text: "<delete message>\nThank you for using mnemospark!" }` where the delete message states cloud delete and cron status (deleted / not found / no matching cron). No structured payload beyond the displayed text.
- **Failure**: `{ text: "Cannot delete file", isError: true }`. No proxy or backend detail in the message.
- **Parameters**: Required `--wallet-address` and `--object-key`. Optional `--location`/`--region`. Used for backend bucket and key and for client cron lookup (object_key).

---

## 8. Sequence Diagram

```mermaid
sequenceDiagram
    participant User
    participant Client as Client<br/>(cloud-command.ts)
    participant Proxy as Local Proxy<br/>(proxy.ts:7120)
    participant APIGW as API Gateway
    participant Auth as WalletAuthorizer<br/>(Lambda)
    participant DeleteLambda as StorageDelete<br/>(Lambda)
    participant S3 as S3
    participant ObjectLog as object.log
    participant CrontabTxt as crontab.txt

    User->>Client: /mnemospark-cloud delete --wallet-address <addr> --object-key <key>
    Note over Client: parseCloudArgs → storageObjectRequest
    Client->>Proxy: POST /mnemospark/storage/delete<br/>{ wallet_address, object_key }
    Note over Proxy: Parse JSON, validate, wallet match, sign
    Proxy->>APIGW: POST /storage/delete<br/>+ body + X-Wallet-Signature
    APIGW->>Auth: Authorize
    Auth-->>APIGW: Allow
    APIGW->>DeleteLambda: Invoke Lambda
    Note over DeleteLambda: parse_input, _require_authorized_wallet
    Note over DeleteLambda: bucket = mnemospark-{wallet_hash}
    DeleteLambda->>S3: head_bucket(bucket)
    alt Bucket not found
        S3-->>DeleteLambda: ClientError
        DeleteLambda-->>APIGW: 404 bucket_not_found
    end
    DeleteLambda->>S3: head_object(bucket, object_key)
    alt Object not found
        S3-->>DeleteLambda: ClientError
        DeleteLambda-->>APIGW: 404 object_not_found
    end
    DeleteLambda->>S3: delete_object(bucket, object_key)
    S3-->>DeleteLambda: OK
    DeleteLambda->>S3: list_objects_v2(bucket, MaxKeys=1)
    S3-->>DeleteLambda: list
    alt Bucket empty
        DeleteLambda->>S3: delete_bucket(bucket)
        S3-->>DeleteLambda: OK
    end
    DeleteLambda-->>APIGW: 200 { success, key, bucket, bucket_deleted }
    APIGW-->>Proxy: 200 + body
    Proxy-->>Client: 200 + body
    Note over Client: Cloud delete succeeded
    Client->>ObjectLog: findLoggedStoragePaymentCronByObjectKey(object_key)
    ObjectLog-->>Client: { cronId, objectKey } or null
    alt Cron entry found
        Client->>CrontabTxt: removeStoragePaymentCronJob(cronId)
        Note over CrontabTxt: Remove line for cronId, rewrite file
        CrontabTxt-->>Client: true/false
    end
    Client-->>User: "File <key> deleted from cloud; cron ... Thank you for using mnemospark!"
```

---

## 9. Recommended Code Changes

Discrepancies or improvements relative to the **goal** (delete the object from S3 and remove the local system cron job that sends payment for the storage object) and general quality:

| # | Change | Repo | Severity | Description |
|---|--------|------|----------|-------------|
| 9.1 | Use canonical command name in proxy messages | **mnemospark** | Low | Proxy error strings say "Invalid JSON body for /mnemospark cloud delete" and "Failed to forward /mnemospark cloud delete". Use `/mnemospark-cloud delete` for consistency. |
| 9.2 | Remove cron job from system crontab | **mnemospark** | High | The goal is to "remove the local system cron job that sends payment for the storage object." The client only updates the **tracking file** `~/.openclaw/mnemospark/crontab.txt`; it does **not** run `crontab` to remove the job from the user’s system crontab. If the system crontab is populated from this file (e.g. by another tool or by documentation), the user’s actual cron job may still run until they re-sync. Recommend: either (a) document that only the tracking file is updated and that the user must remove the job from system crontab manually (or via a documented sync step), or (b) implement removal from the system crontab (e.g. `crontab -l`, filter out the job by identifier/schedule, `crontab -` with the new content) so that "deleted from your system" accurately reflects the system crontab. |
| 9.3 | Surface backend/proxy error detail on failure | **mnemospark** | Low | On delete failure, the handler returns only "Cannot delete file". Including the proxy response body or a short error message would help users distinguish 404 (object not found) from 403/502. |
| 9.4 | Goal alignment summary | — | Verified | The flow **does** delete the object from S3 (and the bucket if empty). Cron-related behavior: the client removes the payment cron **entry from the tracking file** `crontab.txt` only; it does **not** modify the system crontab. If the product goal is to stop the system from running the payment job, 9.2 must be addressed. |

---

## Spec references

- This doc: `meta_docs/cloud-delete-process-flow.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cloud-delete-process-flow.md`
- Cron id reference: `meta_docs/cron-id-usage.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cron-id-usage.md`
- Wallet proof spec: `meta_docs/wallet-proof.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/wallet-proof.md`
- Milestone overview: `meta_docs/e2e-staging-milestone-2026-03-16.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/e2e-staging-milestone-2026-03-16.md`
