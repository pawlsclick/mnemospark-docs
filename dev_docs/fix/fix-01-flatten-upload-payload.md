# Cursor Dev: Flatten Upload Payload Before Backend Forwarding

**ID:** fix-01  
**Repo:** mnemospark

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark. This repo contains the OpenClaw plugin client and the local proxy server that forwards storage requests to the mnemospark-backend API. Do **not** clone, or require access to any other repository; all code and references are in this file References.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Fix the **client-backend request body schema mismatch** that blocks all `/mnemospark_cloud upload` requests.

The client sends a `StorageUploadRequest` with a nested `payload` object (defined in `src/cloud-price-storage.ts` lines 36-54):

```json
{
  "quote_id": "...",
  "wallet_address": "...",
  "object_id": "...",
  "object_id_hash": "...",
  "quoted_storage_price": 1.25,
  "payload": {
    "mode": "inline",
    "content_base64": "<base64-ciphertext>",
    "wrapped_dek": "<base64-wrapped-key>",
    "content_sha256": "...",
    "content_length_bytes": 12345,
    "encryption_algorithm": "AES-256-GCM",
    "bucket_name_hint": "...",
    "key_store_path_hint": "..."
  }
}
```

The backend expects **flat top-level** fields (`ciphertext`, `wrapped_dek`, etc.) per its API Gateway model and `parse_input()`. The proxy currently forwards the client body unchanged via `JSON.stringify(request)` in `forwardStorageUploadToBackend()` at `src/cloud-price-storage.ts` line 457, causing a 400 rejection.

**Changes required:**

1. In `forwardStorageUploadToBackend()` (`src/cloud-price-storage.ts` lines 416-467), transform the `StorageUploadRequest` into the backend's expected flat shape before `JSON.stringify`:
   - Map `request.payload.content_base64` to top-level `ciphertext`.
   - Promote `request.payload.wrapped_dek` to top-level `wrapped_dek`.
   - Promote `request.payload.mode` to top-level `mode`.
   - Promote `request.payload.content_sha256` to top-level `content_sha256`.
   - Promote `request.payload.content_length_bytes` to top-level `content_length_bytes`.
   - Promote `request.payload.encryption_algorithm` to top-level `encryption_algorithm`.
   - Keep `quote_id`, `wallet_address`, `object_id`, `object_id_hash` at top level.
   - Optionally include `object_key` (default to `object_id` if absent), `provider`, `location` from the payload hints.
   - Remove the nested `payload` key and `quoted_storage_price` (the backend ignores it, it uses the quote from DynamoDB).

2. Add or update unit tests in the existing test file(s) to verify:
   - The forwarded JSON body has `ciphertext` at the top level (not nested in `payload`).
   - The forwarded JSON body has `wrapped_dek` at the top level.
   - The `payload` key is not present in the forwarded body.
   - Both `inline` and `presigned` modes produce a valid flat body (for presigned, `ciphertext` should be absent).

## References

- `src/cloud-price-storage.ts` -- `StorageUploadRequest` type (lines 36-54), `UploadPayload` type (lines 36-45), `forwardStorageUploadToBackend()` (lines 416-467), `StorageUploadResponse` type (lines 56-69)
- `src/proxy.ts` -- upload route handler (lines 342-450), calls `forwardStorageUploadToBackend` at line 417
- `src/cloud-command.ts` -- `prepareUploadPayload()` (line 983) builds the `UploadPayload`, upload orchestration (lines 1266-1386)
- `src/cloud-command.test.ts` -- existing test cases for upload command
- Backend expected body (for reference only, do not modify): `{ "quote_id", "wallet_address", "object_id", "object_id_hash", "ciphertext" (base64 string), "wrapped_dek" (base64 string), "object_key" (optional), "provider" (optional), "location" (optional), "mode" (optional) }`

## Agent

- **Install (idempotent):** `npm install`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] `forwardStorageUploadToBackend()` transforms the `StorageUploadRequest` into a flat JSON body before forwarding to the backend
  - [ ] The forwarded body contains `ciphertext` (from `payload.content_base64`) at the top level for inline mode
  - [ ] The forwarded body contains `wrapped_dek` at the top level (promoted from `payload.wrapped_dek`)
  - [ ] The forwarded body does NOT contain a nested `payload` key
  - [ ] For presigned mode, the forwarded body omits `ciphertext` (since `content_base64` is undefined)
  - [ ] The forwarded body includes `mode` at the top level
  - [ ] Existing tests pass (`npm test`)
  - [ ] New or updated tests verify the body flattening for both inline and presigned modes
  - [ ] The agent creates a new branch, commits, and opens a PR

## Task string (optional)

Work only in this repo (mnemospark). In `src/cloud-price-storage.ts`, modify `forwardStorageUploadToBackend()` to flatten the nested `StorageUploadRequest.payload` object into top-level fields before calling `JSON.stringify()`. Map `payload.content_base64` to `ciphertext`, promote `payload.wrapped_dek` and `payload.mode` to top level, and remove the nested `payload` key and `quoted_storage_price`. Add tests verifying the flat body shape for both inline and presigned modes. Run `npm test` to confirm all tests pass. Create a new branch and PR.
