# Cursor Dev: Price-storage require wallet proof when calling backend directly

**ID:** fix-01  
**Repo:** mnemospark

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark. It contains the client, proxy, and cloud modules for mnemospark (price-storage, upload, storage ls/download/delete). Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

The backend now **requires** wallet proof (X-Wallet-Signature) on `POST /price-storage`. When the client calls the backend directly (not via the proxy), `forwardPriceStorageToBackend` in `src/cloud-price-storage.ts` currently adds `X-Wallet-Signature` only when `walletSignature` is present in options; if missing, the backend returns 403 and the caller gets an opaque error.

- In `forwardPriceStorageToBackend`, require `walletSignature` when `backendBaseUrl` is set: if `walletSignature` is missing or empty after normalization, throw a clear error before making the request (e.g. "Wallet proof is required for /price-storage when calling the backend directly. Use the proxy or provide walletSignature.").
- Ensure any callers that use direct backend for quotes pass `walletSignature` (e.g. document in JSDoc or at call sites). The default CLI flow uses the proxy for price-storage, so no CLI change is required unless a code path uses direct backend for quotes; in that case, that path must supply `walletSignature`.

## References

- [mnemospark-backend/docs/README.md](mnemospark-backend/docs/README.md) (public endpoints, wallet proof required).
- [mnemospark-backend/docs/price-storage.md](mnemospark-backend/docs/price-storage.md) (auth: wallet proof).
- `src/cloud-price-storage.ts` (`forwardPriceStorageToBackend`, `BackendQuoteOptions`).

## Agent

- **Install (idempotent):** `npm install`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] `forwardPriceStorageToBackend` throws a clear error when `backendBaseUrl` is set and `walletSignature` is missing or empty after normalization.
  - [ ] JSDoc or call-site comments document that direct backend price-storage requires `walletSignature`.
  - [ ] Existing tests that call `forwardPriceStorageToBackend` with `backendBaseUrl` are updated to pass `walletSignature` where applicable; new or updated tests assert the throw when wallet proof is missing.

## Task string (optional)

Work only in the mnemospark repo. In `src/cloud-price-storage.ts`, require `walletSignature` in `forwardPriceStorageToBackend` when `backendBaseUrl` is set; if missing, throw a clear error so callers get a helpful message instead of a 403. Document the requirement and update tests. Acceptance: [ ] throw when wallet proof missing for direct backend, [ ] docs and tests updated.
