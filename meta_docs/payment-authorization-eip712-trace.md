# Payment authorization header: client build vs backend EIP-712 expectation

Trace of where the payment header is built in the mnemospark client and what the backend expects for EIP-712 (domain, types, message shape). Use this to debug 402 "Payment authorization header is required" or "EIP-712 signature verification failed".

---

## 1. Where the client builds the payment

### 1.1 Entry points

- **Proxy path (typical):** `POST /mnemospark/payment/settle` → proxy forwards to backend `POST /payment/settle` with wallet proof and optional payment.
- **Direct path:** `forwardPaymentSettleToBackend()` in `cloud-price-storage.ts` with `fetchImpl` from `createPaymentFetch(walletPrivateKey).fetch`.

In both cases the **payment is not** sent on the first request. The client sends only:

- Body: `{ quote_id, wallet_address }` (and optionally `payment`, `payment_authorization`).
- Headers: `Content-Type`, `X-Wallet-Signature` (wallet proof). No `PAYMENT-SIGNATURE` or `x-payment` on first call.

The backend responds **402** with headers:

- `PAYMENT-REQUIRED` / `x-payment-required`: base64-encoded JSON `{ "accepts": [ PaymentOption ] }`.

The client’s **x402** layer (`src/x402.ts`) uses `createPaymentFetch(privateKey).fetch`:

1. First request → 402.
2. Reads `payment-required` or `x-payment-required` from the response.
3. Parses it (`parsePaymentRequired` → `decodeBase64Json`), takes `accepts[0]` as the option.
4. Builds a signed payment with `createPaymentPayload(...)`.
5. Retries the **same** request with `payment-signature` and `x-payment` set to that payload.

So the payment header is **built only on retry**, in **`src/x402.ts`**:

- **`createPaymentPayload()`** (lines 120–194): builds EIP-712 signature and envelope.
- **`setPaymentHeaders()`** (114–118): sets `payment-signature` and `x-payment` to the same value.

### 1.2 EIP-712 shape in the client (`src/x402.ts`)

**Domain (for signing):**

- `name`: `option.extra?.name || "USD Coin"` (DEFAULT_TOKEN_NAME).
- `version`: `option.extra?.version || "2"` (DEFAULT_TOKEN_VERSION).
- `chainId`: from `option.network` via `resolveChainId(network)` (e.g. `eip155:8453` → 8453).
- `verifyingContract`: `option.asset` (USDC contract, e.g. `0x833589fCD6EDb6E08f4C7C32D4f71b54bdA02913`).

**Types:**

```ts
TransferWithAuthorization: [
  { name: "from", type: "address" },
  { name: "to", type: "address" },
  { name: "value", type: "uint256" },
  { name: "validAfter", type: "uint256" },
  { name: "validBefore", type: "uint256" },
  { name: "nonce", type: "bytes32" },
]
```

**Message:**

- `from`: wallet address (signer).
- `to`: `option.payTo` (recipient).
- `value`: BigInt(amount) (from 402 `accepts[0].amount` or `maxAmountRequired`).
- `validAfter`: `now - 600` (seconds).
- `validBefore`: `now + maxTimeoutSeconds` (default 300).
- `nonce`: `createNonce()` from `src/nonce.ts` → 32 bytes random, `0x` + 64 hex chars.

**Signature:** `signTypedData()` from viem (privateKey, domain, types, primaryType `"TransferWithAuthorization"`, message). Result is a hex string (e.g. 0x + 130 chars for r,s,v).

**Envelope sent as header (base64 JSON):**

```json
{
  "x402Version": 2,
  "resource": { "url", "description", "mimeType" },
  "accepted": {
    "scheme", "network", "amount", "asset", "payTo",
    "maxTimeoutSeconds", "extra"
  },
  "payload": {
    "signature": "<hex>",
    "authorization": {
      "from": "<address>",
      "to": "<address>",
      "value": "<string amount>",
      "validAfter": "<string>",
      "validBefore": "<string>",
      "nonce": "<0x...hex>"
    }
  },
  "extensions": {}
}
```

Encoded with `encodeBase64Json(paymentData)` and set on both `payment-signature` and `x-payment`.

---

## 2. What the backend expects

### 2.1 Where it’s used

- **Payment/settle:** `services/payment-settle/app.py` calls `payment_core.verify_and_settle_payment(...)`.  
- **Payment “core”** is **`services/storage-upload/app.py`** (loaded dynamically by payment-settle).  
- Verification: `verify_and_settle_payment()` → `_decode_payment_payload(payment_header)` → `_extract_transfer_authorization(payment_payload)` → `_recover_authorization_signer(authorization)`.

### 2.2 Header and body sources

Backend accepts payment from:

- **Headers:** `PAYMENT-SIGNATURE` or `x-payment` (payment-settle uses `payment_core.PAYMENT_SIGNATURE_HEADER_NAMES` → `("payment-signature", "x-payment")`).
- **Body:** `payment`, `payment_authorization`, `payment_signature`, `x_payment` (after normalizing body keys).

First header wins; if none, body fields are used. Value is a **single string**: either raw JSON or **base64-encoded JSON**.

### 2.3 Decode and payload shape (`storage-upload/app.py`)

- **`_decode_payment_payload(payment_header)`** (698–715):  
  Tries base64 decode then JSON parse; expects a JSON object.

- **`_extract_transfer_authorization(payment_payload)`** (725–803):  
  - `signature`: top-level or `payload.signature`; must be non-empty string, `0x` + 130 hex chars (65 bytes).  
  - `authorization`: top-level or `payload.authorization` (or `payload.transferWithAuthorization`).  
  - `accepted`: top-level list or object; used for fallbacks (e.g. to, amount, network, asset, extra).  
  - From `authorization` (with fallbacks to `accepted`):  
    `from`, `to`, `value`, `validAfter`, `validBefore`, `nonce`, `network`, `asset`.  
  - Domain:  
    - `domain_name`: `authorization.name` or `accepted.extra.name` or `payment_payload.tokenName` or `"USD Coin"`.  
    - `domain_version`: `authorization.version` or `accepted.extra.version` or `payment_payload.tokenVersion` or `"2"`.  
  - Builds a `TransferAuthorization` dataclass with these and the signature.

### 2.4 EIP-712 recovery (`_recover_authorization_signer`)

- **Domain:**  
  `name`, `version`, `chainId` from `_chain_id_from_network(authorization.network)`, `verifyingContract` = `authorization.asset`.

- **Types:**  
  `TRANSFER_WITH_AUTH_TYPES` in `storage-upload/app.py` (112–120) — same as client:

  - `TransferWithAuthorization`: from, to, value, validAfter, validBefore, nonce (same types).

- **Message:**  
  `from`, `to`, `value` (int), `validAfter`, `validBefore`, `nonce` (string hex).

- **Recovery:**  
  `encode_typed_data(domain_data, message_types, message_data)` → `Account.recover_message(signable, signature=authorization.signature)`.  
  Recovered address must match `wallet_address` (and other checks: recipient, asset, network, amount, validity window).

---

## 3. Contract: client vs backend

| Item              | Client (`x402.ts`)                    | Backend (`storage-upload/app.py`)           |
|-------------------|----------------------------------------|---------------------------------------------|
| Domain name       | `option.extra?.name` or "USD Coin"     | Same defaults + tokenName / extra           |
| Domain version    | `option.extra?.version` or "2"         | Same defaults + tokenVersion / extra        |
| chainId           | From `option.network` (e.g. 8453)       | From `authorization.network`                |
| verifyingContract | `option.asset`                         | `authorization.asset`                       |
| Primary type      | `TransferWithAuthorization`            | Same                                        |
| Message types     | from, to, value, validAfter, validBefore, nonce | Same                                |
| Signature         | viem `signTypedData` (hex)             | 65-byte hex (0x + 130 chars)                |
| Nonce             | `0x` + 64 hex (bytes32)                | Same, `_normalize_nonce()`                  |

Backend 402 **requirements** (`_payment_requirements`) send `accepts: [ { scheme, network, asset, payTo, amount, extra: { name, version } } ]`. The **extra** object carries the EIP-712 domain name and version (from `payment_config`: `token_name`, `token_version`) so the client signs with the same domain the backend uses for verification. If `extra` were omitted, both sides would rely on defaults "USD Coin" and "2".

---

## 4. Why you might see "EIP-712 signature verification failed"

1. **Domain mismatch**  
   - Different `chainId` (e.g. client Base vs backend expecting same).  
   - Different `verifyingContract` (USDC address) or token name/version.

2. **Message mismatch**  
   - `value` / `validAfter` / `validBefore` or `nonce` encoding (e.g. string vs int, or nonce not 0x+64 hex).  
   - Backend coerces value and validity to int; nonce must match bytes32 (0x + 64 hex).

3. **Signature format**  
   - Backend expects exactly 65 bytes hex (132 chars with 0x). viem’s `signTypedData` usually matches; if you pass through another format (e.g. split r,s,v), it must still decode to 65 bytes.

4. **Network/asset/amount/recipient**  
   - These are checked **after** recovery (to, asset, network, amount, validity). If they differ from quote/config, you get a different error (e.g. "Payment amount is lower than the quote amount"). "EIP-712 signature verification failed" is raised only when `_recover_authorization_signer()` throws (e.g. bad domain/message/signature or eth_account encoding).

5. **bytes32 nonce in Python**  
   - `eth_account.messages.encode_typed_data` may expect `nonce` as bytes or a specific hex format for bytes32. If the backend passes the hex string and the library treats it differently than viem, recovery can fail. Worth verifying eth_account’s expected type for bytes32 in the message.

---

## 5. File reference

| Role              | Repo / path |
|-------------------|-------------|
| Client: build     | mnemospark `src/x402.ts` (`createPaymentPayload`, `setPaymentHeaders`, `handle402`) |
| Client: nonce     | mnemospark `src/nonce.ts` |
| Client: settle    | mnemospark `src/cloud-price-storage.ts` (`forwardPaymentSettleToBackend`, `requestPaymentSettleViaProxy`); `src/cloud-command.ts` (settle-before-upload); `src/proxy.ts` (payment/settle proxy) |
| Backend: verify   | mnemospark-backend `services/storage-upload/app.py` (`verify_and_settle_payment`, `_decode_payment_payload`, `_extract_transfer_authorization`, `_recover_authorization_signer`, `TRANSFER_WITH_AUTH_TYPES`, `_payment_requirements`) |
| Backend: settle   | mnemospark-backend `services/payment-settle/app.py` (parse, quote, call payment_core.verify_and_settle_payment, 402 handling) |
| Docs              | mnemospark-backend `docs/payment-settle.md`, `docs/openapi.yaml` |
