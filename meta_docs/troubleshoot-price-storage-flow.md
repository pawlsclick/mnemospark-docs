# Troubleshooting: price-storage flow (client → proxy → backend)

**Date:** 2026-03-16  
**Revision:** rev 1  
**Milestone:** e2e-staging-2026-03-16 (mnemospark & mnemospark-backend)  
**Repos / components:** mnemospark (client, proxy), mnemospark-backend (price-storage, wallet-authorizer)

When `/mnemospark-cloud price-storage` returns **"Cannot price storage"** with no detail, the failure can be at the client, the local proxy, or the backend. This doc walks through the flow and how to isolate the failing hop.

## Event flow

1. **Client** (OpenClaw plugin): parses the slash command, builds a `PriceStorageQuoteRequest`, and calls `requestPriceStorageViaProxy(request)`.
2. **Client → Proxy**: HTTP `POST http://127.0.0.1:7120/mnemospark/price-storage` with JSON body `{ wallet_address, object_id, object_id_hash, gb, provider, region }`.
3. **Proxy**: Validates body, signs the request (wallet signature), and calls `forwardPriceStorageToBackend()` which HTTP `POST {MNEMOSPARK_BACKEND_API_BASE_URL}/price-storage` with the same JSON and `X-Wallet-Signature`.
4. **Backend** (API Gateway + Lambda): Validates input, runs storage/transfer estimates, persists quote, returns a quote response (e.g. `timestamp`, `quote_id`, `storage_price`, `addr`, `object_id`, `object_id_hash`, `object_size_gb`, `provider`, `location`).
5. **Proxy → Client**: Proxy forwards the backend response (status and body) to the client.
6. **Client**: Parses the response; if OK, appends the quote to object.log and formats a success message. If any step throws (e.g. proxy 502, invalid JSON, missing fields), the client catches and returns **"Cannot price storage"** (and, in newer versions, may append the underlying error message).

## Failure points

| Where | Cause | What you see |
|-------|--------|---------------|
| **Client** | Missing/invalid args (e.g. wrong --gb) | "Cannot price storage: required arguments are ..." or parse error. |
| **Proxy unreachable** | Gateway not running or wrong port | Client throws (e.g. connection refused); you get "Cannot price storage". |
| **Proxy** | `MNEMOSPARK_BACKEND_API_BASE_URL` not set | Proxy returns **502** with body like `{"error":"proxy_error","message":"Failed to forward ...: MNEMOSPARK_BACKEND_API_BASE_URL is not configured"}`. Client shows "Cannot price storage" (and possibly the message). |
| **Proxy → Backend** | Network, TLS, or backend down | Proxy returns 502 with message containing the fetch error. |
| **Backend** | Validation (e.g. provider not `aws`, gb ≤ 0) | Backend returns 400 with a JSON body; proxy forwards it; client gets non-OK status and throws with that body. |
| **Backend** | Lambda/BCM/internal error | Backend returns 500; proxy forwards; client shows "Cannot price storage" (and possibly body). |
| **Client** | Proxy returns 200 but body missing required fields | `parsePriceStorageQuoteResponse` throws; client shows "Cannot price storage". |

## Step-by-step checks

Run these on the machine where OpenClaw (and the mnemospark proxy) runs.

### 1. Proxy reachable and backend URL configured

```bash
curl -s http://127.0.0.1:7120/health | jq .
```

- If connection refused: gateway/proxy not running. Start with `openclaw gateway start` (and ensure `MNEMOSPARK_BACKEND_API_BASE_URL` is set for the process; see [backend-api-base-url.md](backend-api-base-url.md)).
- Expect `"backendConfigured": true`. If `false`, the proxy will return 502 for price-storage because it won’t call the backend.

### 2. Call the proxy directly (same request as the client)

Replace with your real values if needed; the client sends a JSON body like this:

```bash
curl -s -X POST http://127.0.0.1:7120/mnemospark/price-storage \
  -H "Content-Type: application/json" \
  -d '{
    "wallet_address": "0xB261Ea2c20e11576C13D45D5Da431d2Ae0471C7e",
    "object_id": "1772894207186-08b42df60b0233f5",
    "object_id_hash": "f2ccd28f048e8ff252d302019d00ad7b3ae35fbe39f3b7d2ded7788bccb02c89",
    "gb": 0.000403116,
    "provider": "aws",
    "region": "us-east-1"
  }' | jq .
```

- **502 with "MNEMOSPARK_BACKEND_API_BASE_URL is not configured"** → set the env var for the gateway (e.g. Option A or B in [backend-api-base-url.md](backend-api-base-url.md)) and restart the gateway.
- **502 with another message** → read the message (e.g. backend unreachable, TLS error); fix network or backend.
- **400** → proxy validation (e.g. missing fields); adjust the JSON.
- **200** with a quote object → proxy and backend are OK; if the client still fails, the client may be sending different args or the response may be parsed differently (e.g. wrong port or path).

### 3. Call the backend directly (optional)

If you have the backend URL (same as `MNEMOSPARK_BACKEND_API_BASE_URL`):

```bash
BACKEND_URL="https://wrlx6tq7vh.execute-api.us-east-1.amazonaws.com/staging"
curl -s -X POST "${BACKEND_URL}/price-storage" \
  -H "Content-Type: application/json" \
  -d '{
    "wallet_address": "0xB261Ea2c20e11576C13D45D5Da431d2Ae0471C7e",
    "object_id": "1772894207186-08b42df60b0233f5",
    "object_id_hash": "f2ccd28f048e8ff252d302019d00ad7b3ae35fbe39f3b7d2ded7788bccb02c89",
    "gb": 0.000403116,
    "provider": "aws",
    "region": "us-east-1"
  }' | jq .
```

- **400** with a message (e.g. "provider must be aws", "gb must be greater than 0") → fix the request.
- **500** → backend/Lambda issue; check CloudWatch or backend logs.
- **200** with quote → backend is fine; problem is proxy or client (e.g. URL not set for proxy, or client using wrong proxy port).

### 4. OpenClaw / gateway logs

If the gateway runs under systemd, check logs for proxy errors (e.g. "Failed to forward /mnemospark-cloud price-storage"):

```bash
journalctl -u openclaw-gateway.service -n 100 --no-pager
```

Or inspect OpenClaw’s own log file if configured (e.g. under `~/.openclaw`).

## Your exact command

You ran:

```
/mnemospark-cloud price-storage --wallet-address 0xB261Ea2c20e11576C13D45D5Da431d2Ae0471C7e --object-id 1772894207186-08b42df60b0233f5 --object-id-hash f2ccd28f048e8ff252d302019d00ad7b3ae35fbe39f3b7d2ded7788bccb02c89 --gb 0.000403116 --provider aws --region us-east-1
```

Arguments are valid (wallet, object-id, object-id-hash, gb, provider, region). So the most likely causes are:

1. **Proxy did not have `MNEMOSPARK_BACKEND_API_BASE_URL`** when it started (e.g. gateway runs under systemd and the var was only set in your shell). Fix: set it via Option A or B in [backend-api-base-url.md](backend-api-base-url.md), restart gateway, then re-run step 1 and 2.
2. **Proxy → backend** network or TLS failure.
3. **Backend** returned 4xx/5xx (validation or internal error); the proxy forwards the status/body, but the client currently only shows "Cannot price storage" unless the error message is surfaced.

Run step 1 and 2 first; the curl in step 2 will show the real error (502 body or backend response).

## "wallet proof invalid"

If the proxy returns **200** and the backend returns **401/403**, the proxy normalizes that to:

```json
{ "error": "wallet_proof_invalid", "message": "wallet proof invalid" }
```

So the backend authorizer is rejecting the `X-Wallet-Signature` header. Common causes:

1. **EIP-712 type mismatch (nonce/timestamp)**  
   The client signs with `nonce: "string"` and `timestamp: "string"`. The backend authorizer must use the same types when verifying; if it used `bytes32`/`uint256`, the message hash does not match and verification always fails (403, "Incoming identity: null"). **Action:** Deploy a backend wallet-authorizer that uses `nonce: "string"` and `timestamp: "string"` in `MNEMOSPARK_REQUEST_TYPES` and passes `timestamp` as string in the message (see `services/wallet-authorizer/app.py`). After deploying, re-run the request.

2. **Clock skew**  
   The authorizer allows signatures from the last `MNEMOSPARK_AUTH_MAX_AGE_SECONDS` (default 300) and rejects timestamps more than 60 seconds in the future. If the gateway host clock is far off from the backend (Lambda), the signature can be treated as expired or invalid. **Action:** Sync time (e.g. NTP) on the machine running the proxy.

3. **Wrong wallet key**  
   The proxy only adds `X-Wallet-Signature` when the request `wallet_address` matches the proxy’s wallet (from `MNEMOSPARK_WALLET_KEY`). If they match but the key is wrong or from another wallet, the backend will fail to recover the signer. **Action:** Ensure `MNEMOSPARK_WALLET_KEY` in the gateway environment is the private key for `0xB26...` (or whatever address you send).

4. **Path/method mismatch**  
   The signed `method` and `path` must match what the authorizer sees (e.g. `POST` and `/price-storage` after stage stripping). Normally they do; if you use a custom API path or method, ensure the proxy signs the same path/method the authorizer receives.

After fixing, run the same `curl` to the proxy again; you should get a 200 quote response instead of the wallet_proof_invalid body.

---

## Spec references

- This doc: `meta_docs/troubleshoot-price-storage-flow.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/troubleshoot-price-storage-flow.md`
- Price-storage flow: `meta_docs/cloud-price-storage-process-flow.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cloud-price-storage-process-flow.md`
- Backend API base URL: `meta_docs/backend-api-base-url.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/backend-api-base-url.md`
- Backend logs: `meta_docs/backend-logs.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/backend-logs.md`
- Milestone overview: `meta_docs/e2e-staging-milestone-2026-03-16.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/e2e-staging-milestone-2026-03-16.md`
