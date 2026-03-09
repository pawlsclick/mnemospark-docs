# Wallet proof

mnemospark v0.1.11  

The **wallet proof** is a cryptographically signed value that authenticates the client to the mnemospark backend. The client proves it holds the private key for a given wallet address by signing a structured request payload. The backend verifies the signature and can reject requests with invalid or expired proofs.

## How it is created

### 1. Request payload

A **MnemosparkRequest** payload is built from:

| Field           | Description |
|----------------|-------------|
| `method`       | HTTP method, normalized to uppercase (e.g. `GET`, `POST`, `DELETE`). |
| `path`         | Request path, normalized: leading slash, no trailing slash, no query/fragment (e.g. `/price-storage`, `/storage/upload`, `/storage/ls`). |
| `walletAddress`| EVM address (checksummed) of the wallet that will sign. |
| `nonce`        | 32-byte cryptographically random hex string (`0x` + 64 hex chars). From `createNonce()` in `src/nonce.ts`. |
| `timestamp`    | Unix time in seconds (string). |

Implementation: `createMnemosparkRequestPayload()` in `src/mnemospark-request-sign.ts`.

### 2. EIP-712 typed data signing

The payload is signed as **EIP-712** typed data (see [EIP-712](https://eips.ethereum.org/EIPS/eip-712)), using types that align with Solidity and [OpenZeppelin EIP712](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/EIP712.sol) (v4 encoding):

- **Domain**: name `Mnemospark`, version `1`, `chainId` (Base mainnet `8453` or Base Sepolia `84532`), `verifyingContract` `0x0000000000000000000000000000000000000001`.
- **Primary type**: `MnemosparkRequest` with:
  - `method` (string), `path` (string), `walletAddress` (address)
  - `nonce` (**bytes32** — 32-byte hex)
  - `timestamp` (**uint256** — Unix seconds)
- **Signer**: the account derived from the wallet private key. The signer’s address must match `payload.walletAddress`.

Using `bytes32` for nonce and `uint256` for timestamp matches Permit-style structs and keeps encoding consistent with contract-based EIP-712. Signing is done with viem’s `signTypedData()` (private key never leaves the client).

### 3. Header envelope and encoding

The **X-Wallet-Signature** header value is a **base64-encoded JSON** object with:

| Field       | Description |
|------------|-------------|
| `payloadB64` | Base64-encoded JSON of the MnemosparkRequest payload. |
| `signature`  | The EIP-712 signature (hex string). |
| `address`    | The signer’s address (must match payload’s `walletAddress`). |

So: `X-Wallet-Signature: base64(JSON.stringify({ payloadB64, signature, address }))`.

Creation is done by `createWalletSignatureHeaderValue()` in `src/mnemospark-request-sign.ts`. Decoding helpers: `decodeWalletSignatureHeaderValue()`, `decodeWalletSignaturePayload()`.

## Where it is used

### Backend authentication

The wallet proof is sent on **every request to mnemospark backend APIs** that are scoped to a wallet:

- **Price / storage quote**: `POST /price-storage`
- **Upload**: `POST /storage/upload`
- **List**: `POST /storage/ls`
- **Download**: `POST /storage/download`
- **Delete**: `POST /storage/delete`

The client sets the HTTP header:

```http
X-Wallet-Signature: <base64 envelope>
```

The backend:

- Decodes the envelope and payload.
- Verifies the EIP-712 signature for the given domain and message.
- Can enforce nonce/timestamp (e.g. reject expired or replay).
- Returns `403` with `wallet_proof_invalid` (or similar) when the proof is missing, malformed, or fails verification.

So the proof is used to **authenticate the caller as the holder of that wallet** and to **bind the signature to method and path** (and optionally nonce/timestamp).

### Client-side flows

1. **Plugin / OpenClaw (via proxy)**  
   The local mnemospark proxy holds the wallet key. When the plugin sends a storage or price-storage request, the proxy builds the payload for the requested method and path, signs it with the configured wallet, and forwards the request to the backend with `X-Wallet-Signature` set (`src/proxy.ts`, `createBackendWalletSignature` → `createWalletSignatureHeaderValue`).

2. **Direct backend calls (cloud-price-storage, cloud-storage)**  
   When calling the backend from the plugin without the proxy (or from tests), the caller must obtain a wallet proof (method, path, wallet address, private key) and pass it in. The modules `cloud-price-storage.ts` and `cloud-storage.ts` accept an optional `walletSignature` and, when present, set `X-Wallet-Signature` on the outgoing request.

### Error handling

If the backend responds with 403 and a body that looks like a signature/proof/authorization error (e.g. mentions wallet, signature, proof, nonce, timestamp), the proxy and clients map that to a **“wallet proof invalid”** style message so the user knows the problem is with the wallet proof rather than a generic auth failure.

## Summary

| Aspect        | Detail |
|---------------|--------|
| **What**      | EIP-712 signature over a structured request payload (method, path, walletAddress, nonce, timestamp). |
| **Where created** | `src/mnemospark-request-sign.ts` (`createWalletSignatureHeaderValue`, `createMnemosparkRequestPayload`), using `src/nonce.ts` for the nonce. |
| **How sent**  | HTTP header `X-Wallet-Signature` with value = base64(JSON.stringify({ payloadB64, signature, address })). |
| **What it’s for** | Proving to the mnemospark backend that the client controls the given wallet and that the request (method/path) is bound to that proof; backend uses it to authorize storage and pricing operations. |
