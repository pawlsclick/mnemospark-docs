# `trans_id` (transaction id) in mnemospark

**Date:** 2026-03-16  
**Revision:** rev 1  
**Milestone:** e2e-staging-2026-03-16 (mnemospark-backend)  
**Repos / components:** mnemospark-backend (storage-upload payment settlement)

## What `trans_id` represents

`trans_id` is the identifier recorded by the backend for the **USDC payment settlement transaction** associated with a successful `POST /storage/upload`.

It is written into the **upload transaction log** row in DynamoDB and also returned to the client in the upload response.

## How the backend obtains `trans_id`

The upload Lambda (`mnemospark-backend/services/storage-upload/app.py`) verifies the user’s EIP-712 payment authorization and then settles payment in one of two modes controlled by:

- `MNEMOSPARK_PAYMENT_SETTLEMENT_MODE`
  - `mock` (default)
  - `onchain`

### Mode: `mock`

In mock mode, the backend does **not** submit an on-chain transaction.

Instead, it generates a **synthetic** `trans_id` by hashing stable fields and formatting the result to look like a transaction hash:

- Shape: `0x` + 64 hex characters (66 total characters)
- Source: `sha256(f"{quote_id}:{authorization.signature}:{authorization.nonce}:{authorization.value}")`

This `trans_id` **will not exist on BaseScan**, because no chain transaction was sent.

### Mode: `onchain`

In on-chain mode, the backend **does** submit a Base transaction by calling USDC’s `transferWithAuthorization(...)` via `web3`.

It then returns:

- `trans_id = tx_hash.hex()`

In this mode, `trans_id` **is the blockchain transaction hash** (TxHash) you would see on BaseScan.

Example (Base tx):

- `0xfa101ccd9914060cc34d55a7a469c41ea31803ed2e762d6a8787cda75815c639`

## Is `trans_id` the same as a TxHash?

- **`mock` mode:** **No** (synthetic, BaseScan will not find it)
- **`onchain` mode:** **Yes** (`trans_id` == Base TxHash)

---

## Spec references

- This doc: `meta_docs/trans-id-payment-settement.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/trans-id-payment-settement.md`
- Upload flow: `meta_docs/cloud-upload-process-flow.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cloud-upload-process-flow.md`
- Milestone overview: `meta_docs/e2e-staging-milestone-2026-03-16.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/e2e-staging-milestone-2026-03-16.md`
