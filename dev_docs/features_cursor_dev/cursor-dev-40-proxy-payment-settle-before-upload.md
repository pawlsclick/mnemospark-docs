# Cursor Dev: Proxy payment/settle route and upload handler (settle before upload)

**ID:** cursor-dev-40  
**Repo:** mnemospark

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark. It contains the proxy server and cloud modules that forward to the mnemospark backend. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

**Option 1 — Expose proxy route:** The proxy must expose a dedicated path `POST /mnemospark/payment/settle` that forwards to backend `POST /payment/settle`, and the upload handler must call payment/settle before upload. No new user-facing slash command (e.g. `/mnemospark-cloud pay`) is added; user flow remains price-storage → upload. Depends on cursor-dev-39 (client payment/settle API) only if reusing `forwardPaymentSettleToBackend` from the client package; otherwise implement forwarding in proxy.

1. **Add proxy path for payment/settle**
   - Add a new proxy route: `POST /mnemospark/payment/settle` (or equivalent path consistent with existing proxy paths, e.g. `POST /mnemospark/payment/settle`). The handler must:
     - Read and parse the request body (e.g. `quote_id`, `wallet_address`; optional payment payload or headers).
     - Validate that the request wallet matches the proxy’s configured wallet (same pattern as upload handler).
     - Create backend wallet signature for `POST /payment/settle` using the existing `createBackendWalletSignature` pattern.
     - Forward the request to backend `POST /payment/settle` with wallet signature and any incoming `PAYMENT-SIGNATURE` / `x-payment` headers (so that 402 retry from a client can send payment). Optionally use `createPaymentFetch(proxyWalletKey).fetch` when calling the backend so that if the backend returns 402, the proxy can sign and retry payment/settle before responding to the client.
     - Forward the backend response (status, body, headers such as PAYMENT-REQUIRED / x-payment-response) back to the client.
   - Reuse the same backend base URL and wallet-signature logic as other proxy routes (e.g. price-storage, upload).

2. **Upload handler: call payment/settle before upload**
   - In the **upload handler** in `src/proxy.ts`: before calling `forwardStorageUploadToBackend`, call the backend **`POST /payment/settle`** with `quote_id` and `wallet_address` from the upload request body. Use a fetch that handles 402 (e.g. `createPaymentFetch(proxyWalletKey).fetch`) so that if the backend returns 402 with `PAYMENT-REQUIRED`, the proxy signs and retries payment/settle. Only after a successful payment/settle response (200), call `forwardStorageUploadToBackend` **without** `paymentSignature` / `legacyPayment` (do not forward payment headers from the client to the upload request). The backend no longer accepts payment on upload; it only checks the payment ledger.
   - Keep balance checks and other upload-handler logic (e.g. wallet match, idempotency key forwarding) as-is; only the “call payment/settle first, then upload without payment headers” change is required.

3. **Shared forward function (optional)**
   - If the client package (cursor-dev-39) added `forwardPaymentSettleToBackend`, the proxy can import and use it for the new proxy path and for the internal call from the upload handler, passing the proxy’s wallet signature and 402-capable fetch. Otherwise, implement a small inline or local helper in the proxy that POSTs to backend `/payment/settle` with the same contract.

## References

- [mnemospark-backend/docs/payment-settle.md](mnemospark-backend/docs/payment-settle.md) (request/response, 402, headers).
- `src/proxy.ts` (upload handler, createBackendWalletSignature, forwardStorageUploadToBackend, price-storage handler pattern).
- `src/x402.ts` (createPaymentFetch for 402 handling).
- `src/cloud-price-storage.ts` (forwardPaymentSettleToBackend if added in cursor-dev-39; BackendQuoteOptions / wallet signature pattern).

## Agent

- **Install (idempotent):** `npm install`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] New proxy route `POST /mnemospark/payment/settle` exists and forwards to backend `POST /payment/settle` with wallet signature and optional payment headers; 402 is handled (proxy signs and retries) when calling the backend.
  - [ ] Upload handler calls backend `POST /payment/settle` before `forwardStorageUploadToBackend` and uses 402-capable fetch for payment/settle; after 200 from payment/settle, calls `forwardStorageUploadToBackend` without paymentSignature/legacyPayment.
  - [ ] No new user-facing slash command is added; user flow remains price-storage → upload.

## Task string (optional)

Work only in the mnemospark repo. Add proxy route `POST /mnemospark/payment/settle` that forwards to backend with wallet signature and 402 handling. In the upload handler, call backend payment/settle first (with 402 handling), then call forwardStorageUploadToBackend without payment headers. Acceptance: [ ] new proxy path for payment/settle, [ ] upload handler runs payment/settle before upload and does not send payment headers to upload.
