# Cloud Upload Process Flow

End-to-end documentation of the `/mnemospark-cloud upload` command, covering the client, local proxy, and AWS backend.

**Goal**: Successful USDC payment and encrypted file storage in S3.

---

## 1. Command Overview

```
/mnemospark-cloud upload --quote-id <id> --wallet-address <addr> --object-id <id> --object-id-hash <hash>
```

### Required Parameters

| Flag | Description |
|---|---|
| `--quote-id` | ID from a prior `/mnemospark-cloud price-storage` quote |
| `--wallet-address` | EVM wallet address (0x-prefixed, 20-byte hex) |
| `--object-id` | Object identifier from a prior `/mnemospark-cloud backup` step |
| `--object-id-hash` | SHA-256 hash of the local backup archive |

All four flags are mandatory. Missing any causes an immediate client-side error before any network call.

### Prerequisites

1. A local backup archive must exist at `~/.openclaw/mnemospark/backup/<object_id>`.
2. A valid price-storage quote must be logged in `~/.openclaw/mnemospark/object.log`.
3. A wallet private key must be resolvable (env var, or key file on disk).
4. The local proxy must be running on `127.0.0.1:7120`.
5. The wallet must have sufficient USDC balance on Base (chain ID 8453).

---

## 2. Step-by-Step Flow

### 2.1 Client (mnemospark)

**Entry point**: `createCloudCommand()` in `src/cloud-command.ts` (line 1155), registered in `src/index.ts` (line 213).

#### Step 1 -- Argument Parsing

`parseCloudArgs(ctx.args)` extracts the `upload` subcommand and parses the four required `--key value` flags via `parseNamedFlags()`. If any flag is missing, the handler returns `{ text: "Cannot upload storage object: required arguments are ...", isError: true }` immediately.

#### Step 2 -- Quote Lookup from Local Log

`findLoggedPriceStorageQuote(quote_id, homeDir)` reads `~/.openclaw/mnemospark/object.log` to find the price-storage quote matching the given `quote_id`. Validates that the logged quote's `walletAddress`, `objectId`, and `objectIdHash` match the command arguments.

#### Step 3 -- Archive Verification

Checks that the local backup archive exists at `~/.openclaw/mnemospark/backup/<object_id>`, is a file (not a directory), and its SHA-256 hash matches `--object-id-hash`.

#### Step 4 -- Wallet Key Resolution

`resolveWalletPrivateKey(homeDir)` tries, in order:

1. `MNEMOSPARK_WALLET_KEY` environment variable
2. `~/.openclaw/mnemospark/wallet/wallet.key`
3. `~/.openclaw/blockrun/wallet.key`

Derives the address via `privateKeyToAccount(walletKey)` and verifies it matches `--wallet-address`.

#### Step 5 -- Payload Preparation (Client-Side Encryption)

`prepareUploadPayload(archivePath, walletAddress, homeDir)` at line 983:

1. Reads the archive file into memory.
2. Loads (or generates) a 32-byte **KEK** (Key Encryption Key) from `~/.openclaw/mnemospark/keys/<wallet-hash>.key`.
3. Generates a random 32-byte **DEK** (Data Encryption Key).
4. Encrypts file content with **AES-256-GCM** using the DEK.
5. Wraps (encrypts) the DEK with the KEK using AES-256-GCM.
6. Selects upload mode:
   - `"inline"` if encrypted content <= 4,500,000 bytes -- base64-encoded in the JSON body.
   - `"presigned"` if larger -- expects a presigned S3 URL from the backend.
7. Computes SHA-256 of the encrypted content.

Returns an `UploadPayload` object with `mode`, `content_base64` (inline only), `content_sha256`, `content_length_bytes`, `wrapped_dek`, `encryption_algorithm`, `bucket_name_hint`, and `key_store_path_hint`.

#### Step 6 -- Payment Fetch Setup

`createPaymentFetch(walletKey)` (from `src/x402.ts`) creates an x402-aware `fetch` wrapper:

- On the first call, makes the request without payment headers.
- If the response is `402 Payment Required`, extracts payment requirements from `PAYMENT-REQUIRED` / `x-payment-required` headers.
- Signs an EIP-712 `TransferWithAuthorization` message for USDC on Base.
- Retries the request with the signed payment in `PAYMENT-SIGNATURE` / `x-payment` headers.
- Caches payment parameters per endpoint to skip the 402 round trip on subsequent calls.

#### Step 7 -- Upload Request via Proxy

`requestStorageUploadViaProxy()` at `src/cloud-price-storage.ts` line 345:

- **URL**: `POST http://127.0.0.1:7120/mnemospark/upload`
- **Headers**: `Content-Type: application/json`, `Idempotency-Key: <uuid>`, plus x402 payment headers if cached.
- **Body** (JSON): The client sends the `StorageUploadRequest` with a nested `payload` object to the proxy. The proxy's `forwardStorageUploadToBackend()` then flattens this into the backend's expected flat schema before forwarding (see section 2.2, Step 5).

#### Step 8 -- Presigned Upload (if applicable)

`uploadPresignedObjectIfNeeded()` at line 1016: if the backend response includes `upload_url`, PUTs the encrypted content directly to S3 via that presigned URL. If `mode == "presigned"` but no `upload_url` is returned, throws an error.

#### Step 9 -- Post-Upload Logging and Cron

1. `appendStorageUploadLog()` writes a CSV line to `~/.openclaw/mnemospark/object.log` with: timestamp, quote_id, addr, addr_hash, trans_id, storage_price, object_id, object_key, provider, bucket_name, location.
2. `createStoragePaymentCronJob()` creates a monthly cron entry in `~/.openclaw/mnemospark/crontab.txt` (runs on the 1st of each month).
3. `maybeCleanupLocalBackupArchive()` deletes the local archive if `MNEMOSPARK_DELETE_BACKUP_AFTER_UPLOAD` is set.

#### Step 10 -- Return Success Message

Returns to the user:

> Your file `<object_id>` with key `<object_key>` has been stored using `<provider>` in `<bucket_name>` `<location>`
> A cron job `<cronId>` has been configured to send payment monthly (on the 1st) for storage services. If payment is not sent, your `<object_id>` will be deleted after the **32-day deadline** (30-day billing interval + 2-day grace period).
> Thank you for using mnemospark!

---

### 2.2 Local Proxy (mnemospark)

**Entry point**: `src/proxy.ts`, upload route handler at line 342.

The proxy runs on `127.0.0.1:7120` (configurable via `MNEMOSPARK_PROXY_PORT`). It starts automatically when the OpenClaw gateway launches and is registered as an OpenClaw service with `start`/`stop` lifecycle for graceful shutdown.

#### Step 1 -- Parse and Validate Request Body

`readProxyJsonBody(req)` reads the incoming JSON. `parseStorageUploadRequest(payload)` validates the required fields: `quote_id`, `wallet_address`, `object_id`, `object_id_hash`, `quoted_storage_price`, `payload`. Returns 400 if parsing fails.

#### Step 2 -- Wallet Ownership Enforcement

Compares `requestPayload.wallet_address` against the proxy's configured wallet address. If they don't match, returns `403 wallet_proof_invalid`. This ensures only the local wallet owner can initiate uploads.

#### Step 3 -- Wallet Signature Creation

`createBackendWalletSignature("POST", "/storage/upload", walletAddress)` signs an EIP-712 `MnemosparkRequest` typed data message containing the HTTP method, path, wallet address, nonce, and timestamp. The result is base64-encoded and set as the `X-Wallet-Signature` header for the backend.

#### Step 4 -- USDC Balance Check

Calculates `requiredMicros` from `quoted_storage_price * 1,000,000`. Queries the wallet's USDC balance on Base via `BalanceMonitor.checkSufficient(requiredMicros)`. If insufficient, returns:

```json
{
  "error": "insufficient_balance",
  "message": "Insufficient USDC balance. Current: $X.XX, Required: $Y.YY",
  "wallet": "0x...",
  "help": "Fund wallet 0x... on Base before running /mnemospark-cloud upload"
}
```

If balance is low but sufficient, triggers an `onLowBalance` callback (logged as a warning).

#### Step 5 -- Forward to Backend (Payload Flattening)

`forwardStorageUploadToBackend(requestPayload, options)` at `src/cloud-price-storage.ts` line 416:

- **URL**: `POST ${MNEMOSPARK_BACKEND_API_BASE_URL}/storage/upload`
- **Headers**: `Content-Type: application/json`, `X-Wallet-Signature`, `Idempotency-Key`, `PAYMENT-SIGNATURE` / `x-payment` (forwarded from client)
- **Body**: The function builds a flat `backendRequestBody` from the nested `StorageUploadRequest` before serializing. It promotes: `payload.wrapped_dek` to top-level `wrapped_dek`, `payload.content_base64` to top-level `ciphertext` (inline mode only), `payload.mode` to top-level `mode`, and `payload.content_sha256`, `payload.content_length_bytes`, `payload.encryption_algorithm` to top level. The nested `payload` key and `quoted_storage_price` are removed. For presigned mode, `ciphertext` is omitted.

  Flat body sent to backend (inline example):
  ```json
  {
    "quote_id": "...",
    "wallet_address": "...",
    "object_id": "...",
    "object_id_hash": "...",
    "ciphertext": "<base64-encrypted-content>",
    "wrapped_dek": "<base64-wrapped-key>",
    "mode": "inline",
    "content_sha256": "...",
    "content_length_bytes": 12345,
    "encryption_algorithm": "AES-256-GCM",
    "object_key": "..."
  }
  ```

#### Step 6 -- Response Relay

Forwards the backend's status code, body, and payment-related headers (`PAYMENT-REQUIRED`, `PAYMENT-RESPONSE`, `x-payment-required`, `x-payment-response`) back to the client. Normalizes 401/403 auth failures into consistent JSON error bodies. On proxy-level exceptions, returns `502 proxy_error`.

---

### 2.3 Backend (mnemospark-backend)

**Entry point**: `StorageUploadFunction` Lambda, handler at `services/storage-upload/app.py` line 1272.

**Route**: `POST /storage/upload` (defined in `template.yaml` line 567).

#### Step 1 -- API Gateway Request Validation

API Gateway validates the request body against the `StorageUploadRequest` JSON Schema model (`template.yaml` lines 377-409) with `ValidateBody: true`. Required top-level fields: `quote_id`, `wallet_address`, `object_id`, `object_id_hash`, `wrapped_dek`. Note: `ciphertext` is optional (not required) to support presigned upload mode. Additional optional properties: `mode`, `content_sha256`, `content_length_bytes`, `object_key`, `provider`, `location`.

#### Step 2 -- Lambda Authorizer (Wallet Signature Verification)

`WalletRequestAuthorizer` Lambda at `services/wallet-authorizer/app.py` runs before the upload handler:

1. Extracts `X-Wallet-Signature` header (base64-encoded JSON envelope).
2. Decodes the envelope: `payloadB64`, `signature`, `address`.
3. Inner payload: `method`, `path`, `walletAddress`, `nonce`, `timestamp`.
4. Verifies the EIP-712 signature using `eth_account` against the `MnemosparkRequest` typed data schema.
5. Checks signature age (max 300 seconds) and future skew (max 60 seconds).
6. For `/storage/upload`: requires the body's `wallet_address` matches the recovered signer.
7. Returns IAM Allow/Deny policy; on Allow, passes `walletAddress` in authorizer context.

#### Step 3 -- Input Parsing

`parse_input(event)` at line 426:

- Decodes the JSON body via `_collect_request_params`.
- Extracts and validates: `quote_id`, `wallet_address` (normalized to lowercase), `object_id`, `object_id_hash`, `object_key` (defaults to `object_id`), `provider` (defaults to `"aws"`), `location` (defaults to `AWS_REGION`).
- Reads `mode` from params (defaults to `"inline"` if absent; must be `"inline"` or `"presigned"`).
- For inline mode (or when a `ciphertext`/`content` field is present): base64-decodes `ciphertext`. For presigned mode without `ciphertext`: `ciphertext` is set to `None`.
- Reads optional `content_sha256` and `content_length_bytes`.
- Validates `wrapped_dek` as base64.
- Extracts `Idempotency-Key` and payment headers.
- Logs `upload_request_parsed` at INFO level with `quote_id`, `wallet_address`, `object_id`, and `mode`.

#### Step 4 -- Authorized Wallet Double-Check

`_require_authorized_wallet(event, request.wallet_address)` extracts `walletAddress` from `event.requestContext.authorizer` and compares it to the request body's `wallet_address`. Mismatch returns 403. Logs `authorized_wallet_confirmed` at DEBUG level.

#### Step 5 -- Idempotency Check (First Pass)

If `Idempotency-Key` header is present, checks the `upload-idempotency` DynamoDB table:

- If a `completed` entry exists with matching `request_hash`, returns the cached 200 response immediately (short-circuit). For presigned mode, a fresh presigned URL is regenerated even on cache hits. Logs `idempotency_cache_hit`.
- If a `retryable` entry exists (from a previous S3 failure after payment), the handler resumes the upload using the cached payment result, skipping re-verification. Logs `idempotency_retryable_upload_resume`.
- If `in_progress` or hash mismatch, returns `409 conflict`.

#### Step 6 -- Quote Lookup and Validation

`_build_quote_context` at line 494 fetches the quote from the `quotes` DynamoDB table with consistent read and validates:

- Quote exists and has not expired (`expires_at > now`).
- `object_id_hash` matches the quote's stored hash.
- `object_id` matches (if stored on quote).
- `wallet_address` matches (if stored on quote).
- `storage_price > 0`.

Converts `storage_price` to USDC microdollars (`storage_price * 1,000,000`).

#### Step 7 -- Idempotency Lock (Second Pass)

If `Idempotency-Key` is present, `_claim_idempotency_lock` atomically writes an `in_progress` record with `attribute_not_exists` condition to prevent double-execution.

#### Step 8 -- Payment Verification and Settlement

If this is a retryable upload (S3 failure after previous successful payment), payment verification is skipped and the cached `PaymentVerificationResult` is restored from the idempotency record. Logs `payment_settlement_already_confirmed`.

Otherwise, `verify_and_settle_payment()` runs:

1. If no payment header is present, raises `PaymentRequiredError` (402) with payment requirements in `PAYMENT-REQUIRED` / `x-payment-required` headers containing: `scheme`, `network` (eip155:8453), `asset` (USDC address), `payTo` (recipient wallet), `amount` (in microdollars).
2. Decodes the base64-encoded JSON payment payload.
3. Extracts a `TransferAuthorization` (EIP-3009 `transferWithAuthorization` for USDC).
4. Validates: `from` matches wallet, `to` matches configured recipient, asset matches, network matches, amount >= quote amount, `validAfter <= now < validBefore`.
5. Recovers the EIP-712 signer via `eth_account` and verifies it matches `wallet_address`.
6. Settles payment based on `MNEMOSPARK_PAYMENT_SETTLEMENT_MODE`:
   - **onchain** (default): retrieves relayer private key from AWS Secrets Manager, builds and submits a `transferWithAuthorization` transaction to Base mainnet via `web3.py`, waits for receipt (180s timeout), verifies `receipt.status == 1`, returns actual tx hash.
   - **mock** (requires explicit env var override): generates a deterministic pseudo-tx-id via SHA-256 of `quote_id:signature:nonce:value`. No on-chain transaction. A WARNING is logged when mock mode is active.

Logs `payment_verification_succeeded` at INFO level with `trans_id`, settlement mode, `amount`, and `network`.

#### Step 9 -- S3 Upload (mode-dependent)

The handler branches on `mode`:

**Presigned mode** (`mode == "presigned"`):
1. Computes bucket name: `mnemospark-{sha256(wallet_address)[:16]}`.
2. Validates bucket name and ensures bucket exists.
3. Generates a presigned S3 PUT URL via `s3_client.generate_presigned_url('put_object', ...)` with a 1-hour TTL.
4. Logs `presigned_url_generated` at INFO level.
5. Does NOT write ciphertext to S3 — the client will PUT directly using the presigned URL after receiving the response.
6. Does NOT write the transaction log or delete the consumed quote at this stage. Marks the idempotency record as `pending_confirmation` (not `completed`).
7. Returns 200 with `upload_url`, `upload_headers`, and **`confirmation_required: true`**. The client must call `POST /storage/upload/confirm` after successfully uploading to S3 to finalize the transaction.

**Inline mode** (`mode == "inline"`, default):
1. Requires `ciphertext` (raises `BadRequestError` if `None`).
2. `_upload_ciphertext_to_s3()`: computes bucket name `mnemospark-{sha256(wallet_address)[:16]}`, validates bucket name, creates bucket if absent, executes `s3:PutObject` with ciphertext as `Body` and `wrapped-dek` in object `Metadata`.
3. The S3 upload is wrapped in its own `try/except`. On failure:
   - Marks the idempotency record as `retryable` (preserving payment context) so a retry can re-attempt the S3 upload without re-paying.
   - Logs `s3_upload_failed_after_payment` at ERROR level.
   - Returns **207 Multi-Status** with `"upload_failed": true`, the `trans_id`, and payment response headers -- signaling that payment succeeded but storage did not.
4. On success, logs `s3_upload_succeeded` at INFO level.

#### Step 10 -- Transaction Log (inline only; presigned: deferred to confirm)

**Inline mode:** `_write_transaction_log()` writes to the `upload-transaction-log` DynamoDB table with: `quote_id`, `trans_id`, timestamp, payment details (network, asset, amount, status=confirmed, recipient), wallet info, object metadata, provider, bucket, location. Logs `transaction_log_written` at INFO level.

**Presigned mode:** Transaction log is not written here. It is written by the confirm handler when the client calls `POST /storage/upload/confirm` after the S3 PUT succeeds.

#### Step 11 -- Quote Deletion (inline only; presigned: deferred to confirm)

**Inline mode:** Best-effort `delete_item` on the quotes table for the consumed `quote_id`. Failures are silently caught. Logs `consumed_quote_deleted` at DEBUG level.

**Presigned mode:** Quote is not deleted here. It is deleted by the confirm handler after the transaction log is written.

#### Step 12 -- Idempotency Completion and Response

**Inline mode:** If an idempotency lock was acquired, marks it `completed` with the response body and payment response header cached.

**Presigned mode:** Marks idempotency `pending_confirmation` (not `completed`). The confirm handler will mark it `completed` after verifying the S3 object exists.

Returns 200 with:

```json
{
  "quote_id": "...",
  "addr": "0x...",
  "addr_hash": "a3f1b2c4d5e6f7a8",
  "trans_id": "0xabc123...",
  "storage_price": 1.25,
  "object_id": "backup.tar.gz",
  "object_key": "backup.tar.gz",
  "provider": "aws",
  "bucket_name": "mnemospark-a3f1b2c4d5e6f7a8",
  "location": "us-east-1"
}
```

For presigned mode, the response additionally includes:
```json
{
  "upload_url": "https://mnemospark-a3f1b2c4.s3.amazonaws.com/backup.tar.gz?X-Amz-...",
  "upload_headers": { "Content-Type": "application/octet-stream", "x-amz-meta-wrapped-dek": "..." },
  "confirmation_required": true
}
```

Response headers include `PAYMENT-RESPONSE` and `x-payment-response` (base64 JSON with `trans_id`, `network`, `asset`, `amount`).

#### Step 13 -- Confirm Upload (presigned only; client-triggered)

After the client successfully PUTs the encrypted content to the presigned URL, the client calls **`POST /storage/upload/confirm`** (handled by `StorageUploadConfirmFunction` in the same `app.py`). The confirm handler:

1. Parses the JSON body: `wallet_address`, `object_key`, `idempotency_key`, `quote_id`.
2. Verifies the request wallet matches the authorizer context (`X-Wallet-Signature`).
3. Looks up the idempotency record. If status is already `completed`, returns the cached 200 response. If status is `pending_confirmation`, continues.
4. Verifies the S3 object exists via `head_object` on the wallet-scoped bucket and `object_key`. If the object is missing, returns **404** with a message that the client must upload via the presigned URL first.
5. Writes the transaction log (`_write_transaction_log()`).
6. Deletes the consumed quote (best-effort).
7. Marks the idempotency record `completed`.
8. Returns 200 with the same response shape as a completed upload (without `upload_url`, `upload_headers`, or `confirmation_required`).

If the client never calls confirm, the idempotency record expires after 24 hours and the quote remains in the quotes table (until its own TTL).

---

### 2.4 Return Path Summary

**Inline upload:**
```
Backend 200 + payment-response headers
  -> Proxy relays status, body, and payment headers to client
    -> Client x402 wrapper resolves the final response
      -> requestStorageUploadViaProxy parses the JSON response (or retries on 207, then parses 200)
        -> appendStorageUploadLog (write to object.log)
          -> createStoragePaymentCronJob (write to crontab.txt)
            -> maybeCleanupLocalBackupArchive (optional)
              -> Return success message to user
```

**Presigned upload:**
```
Backend 200 + upload_url + confirmation_required: true
  -> Proxy relays to client
    -> requestStorageUploadViaProxy parses the JSON response
      -> uploadPresignedObjectIfNeeded (PUT to S3 using presigned URL)
        -> Client calls POST /storage/upload/confirm (via proxy) with wallet_address, object_key, idempotency_key, quote_id
          -> Backend confirm handler verifies S3 object exists, writes transaction log, marks idempotency completed
        -> appendStorageUploadLog (write to object.log)
          -> createStoragePaymentCronJob (write to crontab.txt)
            -> maybeCleanupLocalBackupArchive (optional)
              -> Return success message to user
```

---

## 3. Files Used Across the Path

### Client and Proxy (mnemospark repo)

| File | Role |
|---|---|
| `src/index.ts` | Plugin entrypoint; registers the `/mnemospark-cloud` command and starts the proxy |
| `src/cloud-command.ts` | Command definition, argument parsing, upload orchestration, AES-256-GCM encryption, presigned upload, post-upload logging/cron |
| `src/cloud-price-storage.ts` | `StorageUploadRequest`/`UploadPayload` types, `requestStorageUploadViaProxy()`, `forwardStorageUploadToBackend()`, request/response parsing |
| `src/proxy.ts` | Local HTTP proxy server; routes `/mnemospark/upload` to backend, adds wallet signatures, checks USDC balance |
| `src/x402.ts` | x402 payment fetch wrapper; handles 402 responses with EIP-712 signed USDC `TransferWithAuthorization` |
| `src/mnemospark-request-sign.ts` | Creates `X-Wallet-Signature` EIP-712 header for backend authentication |
| `src/config.ts` | `PROXY_PORT` (default 7120) and `MNEMOSPARK_BACKEND_API_BASE_URL` |
| `src/balance.ts` | `BalanceMonitor` -- USDC balance checking on Base chain |
| `src/payment-cache.ts` | Caches x402 payment parameters to skip 402 round trips |
| `src/nonce.ts` | Generates cryptographic nonces |
| `src/wallet-key.ts` | Wallet private key validation |
| `src/wallet-signature.ts` | Wallet signature normalization |
| `src/auth.ts` | Wallet key resolution for proxy startup |
| `src/cloud-utils.ts` | Shared utilities (`normalizeBaseUrl`, `asRecord`, etc.) |
| `src/types.ts` | OpenClaw plugin type definitions (`OpenClawPluginCommandDefinition`) |

### Backend (mnemospark-backend repo)

| File | Role |
|---|---|
| `services/storage-upload/app.py` | Main upload Lambda handler: input parsing, wallet authorization, idempotency (retryable + `pending_confirmation`), quote validation, payment verification/settlement (onchain default), S3 upload (inline + presigned), S3 failure rollback (207), presigned two-phase flow (defers transaction log until confirm). Also `confirm_upload_handler()` for `POST /storage/upload/confirm`: verifies S3 object via `head_object`, writes transaction log, marks idempotency completed. Structured JSON logging throughout. |
| `services/storage-upload/requirements.txt` | Dependencies: `boto3`, `eth-account`, `web3` |
| `services/wallet-authorizer/app.py` | Lambda authorizer: EIP-712 wallet proof verification, signature age checking |
| `template.yaml` | SAM template: route definitions (`/storage/upload`, `/storage/upload/confirm`), IAM roles, DynamoDB tables (`QuotesTable`, `UploadTransactionLogTable`, `UploadIdempotencyTable`), environment variables, API Gateway models (`StorageUploadRequest`, `UploadConfirmRequest`), `StorageUploadFunction` and `StorageUploadConfirmFunction`, CloudWatch alarms |

### Local Filesystem (user machine)

| Path | Role |
|---|---|
| `~/.openclaw/mnemospark/object.log` | Persistent log of quotes, uploads, and cron entries (CSV format) |
| `~/.openclaw/mnemospark/crontab.txt` | Monthly payment cron job entries |
| `~/.openclaw/mnemospark/backup/<object_id>` | Local backup archive (input to upload) |
| `~/.openclaw/mnemospark/wallet/wallet.key` | Wallet private key file |
| `~/.openclaw/mnemospark/keys/<wallet-hash>.key` | AES-256 KEK for envelope encryption |

---

## 4. Logging

### Client Plugin (`src/index.ts`)

- `api.logger.info(...)` -- proxy startup, wallet info, balance checks.
- `api.logger.error(...)` -- proxy errors.
- `api.logger.warn(...)` -- low balance warnings.

### Local Proxy (`src/proxy.ts`)

- `console.error("[mnemospark] Request stream error: ...")` -- stream read failures.
- `console.warn("[mnemospark] Failed to create wallet proof...")` -- signature creation failures.
- `console.log("[mnemospark] Existing proxy detected...")` -- proxy reuse detection.

### Persistent File Logging (Client)

- `~/.openclaw/mnemospark/object.log` -- append-only CSV with backup, quote, and upload records.
- `~/.openclaw/mnemospark/crontab.txt` -- cron job entries for monthly payments.

### Backend (AWS)

- **Lambda Structured Logging**: The handler uses `logging.getLogger(__name__)` with a `_log_event()` helper that emits structured JSON with an `event` key. Key events logged:
  - INFO: `upload_request_parsed`, `authorized_wallet_confirmed`, `quote_lookup_succeeded`, `idempotency_lock_acquired`, `payment_verification_succeeded`, `presigned_url_generated`, `s3_upload_succeeded`, `transaction_log_written`.
  - WARNING: `upload_request_forbidden`, `upload_request_bad_request`, `upload_quote_not_found`, `upload_payment_required`, `upload_idempotency_conflict`, mock-mode activation warning.
  - ERROR: `s3_upload_failed_after_payment`, `upload_internal_error`, `idempotency_mark_retryable_failed`.
  - DEBUG: `authorized_wallet_confirmed`, `consumed_quote_deleted`.
  - Retryable upload flow: `idempotency_retryable_upload_resume`, `idempotency_cache_hit`, `payment_settlement_already_confirmed`, `quote_context_restored_from_idempotency`.
- **Lambda Log Groups**: `StorageUploadFunctionLogGroup` with configurable retention (`ObservabilityLogRetentionDays`, default 30 days).
- **API Gateway Access Logs**: `ApiGatewayAccessLogsLogGroup` capturing request metadata (requestId, IP, method, path, status, latency).
- **CloudTrail**: `MnemosparkCloudTrail` for management event auditing.
- **CloudWatch Alarms**: 4XX errors, 5XX errors, throttling, and latency alarms.

---

## 5. Success

### What the User Sees

```
Your file `backup.tar.gz` with key `backup.tar.gz` has been stored using `aws`
in `mnemospark-a3f1b2c4` `us-east-1`
A cron job `cron-abc123` has been configured to send payment monthly (on the 1st)
for storage services. If payment is not sent, your `backup.tar.gz` will be deleted
after the **32-day deadline** (30-day billing interval + 2-day grace period).
Thank you for using mnemospark!
```

### What Gets Written

**object.log** -- new CSV line:

```
2026-03-09 12:00:00,quote-123,0x1111...1111,a3f1b2c4,0xabc123,1.25,backup.tar.gz,backup.tar.gz,aws,mnemospark-a3f1b2c4,us-east-1
```

**crontab.txt** -- new cron entry for monthly payment on the 1st.

### Backend Side Effects

1. Ciphertext stored in S3 bucket `mnemospark-{wallet_hash}` with `wrapped-dek` metadata.
2. Transaction log row written to `upload-transaction-log` DynamoDB table.
3. Consumed quote deleted from `quotes` DynamoDB table (best-effort).
4. Idempotency record marked `completed` in `upload-idempotency` DynamoDB table (if Idempotency-Key was provided).

---

## 6. Failure Scenarios

### Client-Side Failures (before network call)

| Condition | Error Message | `isError` |
|---|---|---|
| Missing required flags | `"Cannot upload storage object: required arguments are --quote-id, --wallet-address, --object-id, --object-id-hash."` | true |
| Quote not found in object.log | `"Cannot upload storage object: quote-id not found in object.log. Run /mnemospark-cloud price-storage first."` | true |
| Quote details mismatch | `"Cannot upload storage object: quote details do not match wallet/object arguments."` | true |
| Archive not found locally | `"Cannot upload storage object: local archive not found at <path>. Run /mnemospark-cloud backup first."` | true |
| Archive is not a file | `"Cannot upload storage object: local archive path is not a file (<path>)."` | true |
| Archive hash mismatch | `"Cannot upload storage object: object-id-hash does not match local archive."` | true |
| Wallet address mismatch | `"Cannot upload storage object: wallet key address <derived> does not match --wallet-address <given>."` | true |

### Proxy-Side Failures

| Status | Error Key | Condition |
|---|---|---|
| 400 | `Bad request` | Invalid JSON body or missing required fields |
| 400 | `insufficient_balance` | Wallet USDC balance < quoted price |
| 400 | (wallet required) | Failed to create wallet signature |
| 403 | `wallet_proof_invalid` | Request wallet does not match proxy wallet |
| 502 | `proxy_error` | Backend forwarding failure (network error, timeout, etc.) |

### Backend-Side Failures

| Status | Error Key | Condition |
|---|---|---|
| 207 | `upload_failed` | S3 upload failed after payment was settled. Payment is confirmed (`trans_id` included in response) but file was not stored. Idempotency record is marked `retryable` — client can retry with the same Idempotency-Key to re-attempt S3 upload without re-paying. |
| 400 | `Bad request` | Missing/invalid fields, hash mismatch, validation failure |
| 404 | `S3 object not found` | (Confirm endpoint only) The object does not exist in S3 at the expected bucket/key. Client must complete the presigned PUT before calling confirm. |
| 402 | `payment_required` | No payment header, invalid payment, amount too low, expired authorization, signer mismatch |
| 403 | `forbidden` | Missing or mismatched wallet authorizer context |
| 404 | `quote_not_found` | Quote missing or expired |
| 409 | `conflict` | Idempotency-Key reuse with different payload, or upload already in progress |
| 500 | `Internal error` | Unhandled exceptions (DynamoDB failure, relayer error, etc.) |

The 402 response includes `PAYMENT-REQUIRED` and `x-payment-required` headers with base64-encoded payment requirements:

```json
{
  "accepts": [{
    "scheme": "exact",
    "network": "eip155:8453",
    "asset": "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913",
    "payTo": "0x47d241ae97fe37186ac59894290ca1c54c060a6c",
    "amount": "1250000"
  }]
}
```

---

## 7. Sequence Diagram

```mermaid
sequenceDiagram
    participant User
    participant Client as Client<br/>(cloud-command.ts)
    participant Proxy as Local Proxy<br/>(proxy.ts:7120)
    participant APIGW as API Gateway
    participant Auth as WalletAuthorizer<br/>(Lambda)
    participant Upload as StorageUpload<br/>(Lambda)
    participant Confirm as StorageUploadConfirm<br/>(Lambda)
    participant DDB as DynamoDB
    participant S3 as S3

    User->>Client: /mnemospark-cloud upload --quote-id ... --wallet-address ... --object-id ... --object-id-hash ...

    Note over Client: Parse args, validate flags
    Note over Client: Lookup quote in object.log
    Note over Client: Verify archive exists and hash matches
    Note over Client: Resolve wallet key, verify address
    Note over Client: Encrypt file (AES-256-GCM envelope)
    Note over Client: Select mode: inline (<4.5MB) or presigned
    Note over Client: Create x402 payment-aware fetch

    Client->>Proxy: POST /mnemospark/upload<br/>{quote_id, wallet_address, object_id,<br/>object_id_hash, quoted_storage_price,<br/>payload: {mode, content_base64?, wrapped_dek, ...}}

    Note over Proxy: Parse JSON, validate fields
    Note over Proxy: Enforce wallet ownership
    Note over Proxy: Check USDC balance on Base

    alt Insufficient balance
        Proxy-->>Client: 400 insufficient_balance
        Client-->>User: Error: Insufficient USDC balance
    end

    Note over Proxy: Sign EIP-712 MnemosparkRequest<br/>(X-Wallet-Signature header)
    Note over Proxy: Flatten payload to backend schema

    Proxy->>APIGW: POST /storage/upload<br/>{quote_id, wallet_address, ciphertext?,<br/>wrapped_dek, mode, ...}<br/>+ X-Wallet-Signature<br/>+ Idempotency-Key<br/>+ PAYMENT-SIGNATURE

    APIGW->>Auth: Authorize (X-Wallet-Signature)
    Note over Auth: Decode envelope, verify EIP-712<br/>signature, check age, match wallet
    Auth-->>APIGW: Allow (walletAddress in context)

    APIGW->>Upload: Invoke Lambda
    Note over Upload: LOG: upload_request_parsed

    Note over Upload: parse_input, verify authorized wallet

    Upload->>DDB: Check idempotency (upload-idempotency table)

    alt Cached completed result
        DDB-->>Upload: Completed entry found
        Note over Upload: LOG: idempotency_cache_hit
        Upload-->>APIGW: 200 (cached response)
    else Retryable (S3 failed after payment)
        DDB-->>Upload: Retryable entry found
        Note over Upload: LOG: idempotency_retryable_upload_resume
        Note over Upload: Restore cached payment result<br/>(skip payment re-verification)
    end

    Upload->>DDB: Get quote (quotes table, ConsistentRead)
    Note over Upload: Validate quote: not expired,<br/>hashes match, price > 0
    Note over Upload: LOG: quote_lookup_succeeded

    Upload->>DDB: Claim idempotency lock (in_progress)
    Note over Upload: LOG: idempotency_lock_acquired

    alt No payment header
        Upload-->>APIGW: 402 payment_required<br/>+ PAYMENT-REQUIRED headers
        APIGW-->>Proxy: 402
        Proxy-->>Client: 402 + payment requirements

        Note over Client: x402 wrapper signs EIP-712<br/>TransferWithAuthorization

        Client->>Proxy: POST /mnemospark/upload (retry)<br/>+ PAYMENT-SIGNATURE header
        Proxy->>APIGW: POST /storage/upload (retry)<br/>+ PAYMENT-SIGNATURE
        APIGW->>Auth: Re-authorize
        Auth-->>APIGW: Allow
        APIGW->>Upload: Invoke Lambda
    end

    Note over Upload: verify_and_settle_payment:<br/>decode payment, validate fields,<br/>recover EIP-712 signer,<br/>settle (onchain default, mock opt-in)
    Note over Upload: LOG: payment_verification_succeeded

    alt mode == presigned
        Upload->>S3: generate_presigned_url(put_object, 1hr TTL)
        S3-->>Upload: presigned PUT URL
        Note over Upload: LOG: presigned_url_generated
        Note over Upload: Mark idempotency<br/>pending_confirmation<br/>(no transaction log yet)
    else mode == inline
        Upload->>S3: PutObject (ciphertext + wrapped-dek metadata)

        alt S3 PutObject fails
            S3-->>Upload: Error
            Note over Upload: LOG: s3_upload_failed_after_payment (ERROR)
            Upload->>DDB: Mark idempotency retryable<br/>(preserve payment context)
            Upload-->>APIGW: 207 {upload_failed: true,<br/>trans_id, error_message}<br/>+ PAYMENT-RESPONSE headers
            APIGW-->>Proxy: 207
            Proxy-->>Client: 207 (payment ok, S3 failed)
            Note over Client: Client can retry with same<br/>Idempotency-Key to re-attempt S3
        end

        S3-->>Upload: Success
        Note over Upload: LOG: s3_upload_succeeded
    end

    alt mode == inline
        Upload->>DDB: Write transaction log (upload-transaction-log table)
        Note over Upload: LOG: transaction_log_written
        Upload->>DDB: Delete consumed quote (best-effort)
        Upload->>DDB: Mark idempotency completed
    end

    Upload-->>APIGW: 200 {quote_id, addr, trans_id,<br/>bucket_name, upload_url?,<br/>confirmation_required? ...}<br/>+ PAYMENT-RESPONSE headers
    APIGW-->>Proxy: 200
    Proxy-->>Client: 200 + payment response headers

    Note over Client: Parse upload response

    alt Presigned mode
        Note over Client: uploadPresignedObjectIfNeeded
        Client->>S3: PUT upload_url (encrypted content)
        S3-->>Client: 200
        Note over Client: confirmation_required: true
        Client->>Proxy: POST /mnemospark/upload/confirm<br/>{wallet_address, object_key, idempotency_key, quote_id}
        Proxy->>APIGW: POST /storage/upload/confirm<br/>+ X-Wallet-Signature
        APIGW->>Auth: Authorize
        Auth-->>APIGW: Allow
        APIGW->>Confirm: Invoke Lambda
        Confirm->>DDB: Get idempotency (pending_confirmation)
        Confirm->>S3: head_object (verify object exists)
        S3-->>Confirm: 200
        Confirm->>DDB: Write transaction log
        Confirm->>DDB: Delete consumed quote
        Confirm->>DDB: Mark idempotency completed
        Confirm-->>APIGW: 200 (final response)
        APIGW-->>Proxy: 200
        Proxy-->>Client: 200
    end

    Note over Client: Append to object.log
    Note over Client: Create cron job in crontab.txt
    Note over Client: Optional: delete local archive

    Client-->>User: Success message with storage details and cron info
```

---

## 8. Code Changes -- Status

All five issues identified during the original code audit have been implemented across the `mnemospark` and `mnemospark-backend` repositories.

| # | Issue | Severity | Status | Fix |
|---|---|---|---|---|
| 8.1 | Client-Backend Request Body Schema Mismatch | Blocker | **RESOLVED** | `forwardStorageUploadToBackend()` in `mnemospark/src/cloud-price-storage.ts` now builds a flat `backendRequestBody` (lines 480-506), promoting `payload.*` fields to top level and omitting the nested `payload` key. Backend API Gateway model (`template.yaml` lines 377-409) updated: `ciphertext` removed from `required`, `mode`/`content_sha256`/`content_length_bytes` added as optional properties. |
| 8.2 | Presigned URL Path Not Implemented | Blocker (>4.5 MB) | **RESOLVED** | Backend `lambda_handler` branches on `request.mode`. For `"presigned"`: generates a 1-hour presigned S3 PUT URL (`app.py` lines 1431-1453) and returns it as `upload_url` + `upload_headers`. `parse_input()` accepts `mode` and makes `ciphertext` optional. `_request_fingerprint()` handles `ciphertext is None` using `content_sha256`. Cached idempotency responses regenerate fresh presigned URLs. |
| 8.3 | No Explicit Logging in Backend Lambda | Medium | **RESOLVED** | `app.py` initializes `logger = logging.getLogger(__name__)` (line 30) with a `_log_event()` helper (line 186) for structured JSON logging. 20+ log points at INFO/WARNING/ERROR/DEBUG levels covering parsing, auth, idempotency, payment, S3, transaction log, and all error handlers. |
| 8.4 | Payment Before S3 Upload -- No Rollback | High | **RESOLVED** | S3 upload is wrapped in its own `try/except` (lines 1456-1526). On S3 failure after payment: idempotency record is marked `retryable` via `_mark_idempotency_upload_retryable()` (preserving payment context), logs `s3_upload_failed_after_payment` at ERROR, and returns **207 Multi-Status** with `upload_failed: true` and `trans_id`. Retries with the same Idempotency-Key skip payment re-verification. |
| 8.5 | Settlement Mode Defaults to `mock` | Medium | **RESOLVED** | `_settlement_mode()` (line 795) now defaults to `"onchain"`. `template.yaml` parameter `PaymentSettlementMode` default changed to `onchain`. A WARNING is logged when mock mode is explicitly activated. |

---

## 9. Post–Phase 3 Items — Status

The following items were identified after the original five fixes (8.1–8.5). They are assessed against the goal of **successful on-chain payment and file upload to S3**.

| # | Issue | Severity | Status | Notes |
|---|---|---|---|---|
| 9.1 | Client Does Not Handle 207 (S3 Failure After Payment) | High | **RESOLVED (backend)** | **Backend (mnemospark-backend):** Returns 207 with `upload_failed: true` and `trans_id`; idempotency marked `retryable` so retries skip payment. **Client (mnemospark):** fix-06 adds auto-retry in `requestStorageUploadViaProxy()` and clear error with `trans_id` when retries are exhausted. |
| 9.2 | Presigned Upload Has No Backend Confirmation Step | Medium | **RESOLVED (backend)** | **Backend (mnemospark-backend):** Two-phase presigned flow implemented. Presigned uploads mark idempotency `pending_confirmation`, return `confirmation_required: true`, and defer transaction log and quote deletion. `POST /storage/upload/confirm` (StorageUploadConfirmFunction) verifies S3 object via `head_object`, then writes transaction log, deletes quote, and marks idempotency `completed`. **Client (mnemospark):** fix-08 adds `confirmPresignedUploadViaProxy()` and proxy route for `/mnemospark/upload/confirm`; upload handler calls confirm after presigned S3 PUT when `confirmation_required` is true. |
| 9.3 | Client x402 Retry Sends Full Body to Proxy Again | Low | **NOT IMPLEMENTED** | When the x402 wrapper retries after 402, it re-sends the full request body. For presigned mode the body is small; impact is negligible. No fix required at this time. Note for future consideration. |

---

## 10. Remaining Blockers to Successful Payment and S3 Upload

With 9.1 and 9.2 implemented **in mnemospark-backend**, the backend supports:

- **Inline:** 207 on S3 failure after payment, retryable idempotency, and full success path.
- **Presigned:** Two-phase flow with `confirmation_required` and `POST /storage/upload/confirm`.

For **end-to-end success** (payment + file in S3):

- **Inline:** The client (mnemospark) must handle 207 with auto-retry (fix-06). If the client has not been updated, a 207 response still causes `parseStorageUploadResponse()` to throw and the user sees a generic error; the backend is ready for retries.
- **Presigned:** The client (mnemospark) must call the confirm endpoint after the presigned S3 PUT (fix-08). If the client has not been updated, the transaction log is never written and the upload is not finalized until/unless the client is updated to call confirm.

**No additional backend fixes are required** for the stated goal. Any remaining gaps are client-side (fix-06 and fix-08 in mnemospark) if those have not yet been implemented.
