# Cursor Dev: Client payment/settle API and upload flow (settle before upload)

**ID:** cursor-dev-39  
**Repo:** mnemospark

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark. It contains the client, proxy, cloud-price-storage, cloud-storage, x402 payment flow, and cloud-command upload orchestration. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

The backend now requires payment to be **settled first** via `POST /payment/settle`; only after a successful settlement can `POST /storage/upload` succeed. Upload no longer accepts or uses `PAYMENT-SIGNATURE` / `x-payment`; it only checks the payment ledger. This task adds the client-side payment/settle API and updates the upload flow so that payment/settle is called before upload (with 402 handling), and upload no longer sends payment headers.

1. **Add payment/settle API**
   - Add `forwardPaymentSettleToBackend(quoteId, walletAddress, options)` that calls backend `POST /payment/settle`. Implement in `src/cloud-price-storage.ts` or a new `src/cloud-payment.ts`. Options must include `backendBaseUrl`, `walletSignature`, and `fetchImpl` (for 402 handling). Request body: `{ quote_id, wallet_address }`; support payment via `PAYMENT-SIGNATURE` / `x-payment` header or inline body per backend [payment-settle.md](mnemospark-backend/docs/payment-settle.md). Return status, bodyText, contentType, and optional paymentRequired/paymentResponse headers.
   - Optionally add `requestPaymentSettleViaProxy(quoteId, walletAddress, options)` that POSTs to the proxy path `POST /mnemospark/payment/settle` (for use when proxy is used and cursor-dev-40 has added that route). If the proxy route does not exist yet, this can be a stub or implemented to call the proxy path once it exists.
   - Export types for the settle request/response and options so the proxy (cursor-dev-40) can reuse them if needed.

2. **Upload flow in cloud-command**
   - In `src/cloud-command.ts`, in the upload branch: before calling `requestStorageUpload`, call the new payment/settle (e.g. `forwardPaymentSettleToBackend` when using direct backend, or the proxy variant when using proxy). Use `createPaymentFetch(walletKey).fetch` as `fetchImpl` for the payment/settle call so that if the backend returns 402 with `PAYMENT-REQUIRED`, the client signs and retries payment/settle. Only after a successful payment/settle response (200), call `requestStorageUpload` with a **plain fetch** (do not pass the payment fetch as `fetchImpl` for upload, and do not pass payment headers). Remove reliance on upload returning 402 with payment requirements.
   - Ensure the upload request still receives the same quote_id and wallet_address so the backend finds the settled payment in the ledger.

3. **Stop sending payment headers on upload**
   - In `forwardStorageUploadToBackend` in `src/cloud-price-storage.ts`, stop setting `PAYMENT-SIGNATURE` and `x-payment` on the request (or make them no-ops). The backend no longer uses them on upload; payment is already settled via `/payment/settle`. Options `paymentSignature` and `legacyPayment` can be ignored or removed from the upload call path.

4. **Tests**
   - Update or add tests so that the upload flow (direct backend and/or proxy) exercises: payment/settle called first, then upload without payment headers. Mock or stub backend responses as needed. Ensure existing upload tests that assumed 402-on-upload are updated to the new settle-then-upload flow.

## References

- [mnemospark-backend/docs/payment-settle.md](mnemospark-backend/docs/payment-settle.md) (request/response, 402, headers).
- [mnemospark-backend/docs/storage-upload.md](mnemospark-backend/docs/storage-upload.md) (payment required: call payment/settle first).
- `src/cloud-command.ts` (upload branch, requestStorageUpload, createPaymentFetch).
- `src/cloud-price-storage.ts` (forwardStorageUploadToBackend, BackendUploadOptions).
- `src/x402.ts` (createPaymentFetch, 402 handling).

## Agent

- **Install (idempotent):** `npm install`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] `forwardPaymentSettleToBackend(quoteId, walletAddress, options)` exists and calls backend `POST /payment/settle` with wallet signature and optional payment headers; supports 402 via `fetchImpl`.
  - [ ] Upload flow in `cloud-command.ts` calls payment/settle before `requestStorageUpload` and uses plain fetch (no payment header) for upload.
  - [ ] `forwardStorageUploadToBackend` no longer sends `PAYMENT-SIGNATURE` / `x-payment` on upload (or they are no-ops).
  - [ ] Tests cover the settle-then-upload flow; existing upload tests updated for the new behavior.

## Task string (optional)

Work only in the mnemospark repo. Add a payment/settle API that calls backend `POST /payment/settle` with wallet proof and 402 handling. In the upload flow, call payment/settle first (using createPaymentFetch for 402), then call requestStorageUpload with plain fetch and no payment headers. Stop sending payment headers on upload in forwardStorageUploadToBackend. Update tests for the new flow. Acceptance: [ ] payment/settle API and upload flow updated, [ ] upload does not send payment headers, [ ] tests pass.
