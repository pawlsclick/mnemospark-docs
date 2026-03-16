# End-to-end staging milestone: backup → quote → upload → ls → download → hash match

**Date:** 2026-03-16  
**Revision:** rev 1  
**Milestone:** e2e-staging-2026-03-16 (mnemospark & mnemospark-backend)  
**Git tags:**  
- `mnemospark`: `milestone/e2e-staging-2026-03-16`  
- `mnemospark-backend`: `milestone/e2e-staging-2026-03-16`

This spec captures the known-good baseline for the first full staging end-to-end test:

> **backup → price-storage quote → upload (payment) → ls → download → local hash match**

and ties it to the code versions referenced by the tags above.

## Overview

At this milestone, the mnemospark client, proxy, and backend support a complete encrypted cloud storage flow:

1. **Backup**: Local tar+gzip archive built and logged.
2. **Price-storage**: Backend computes a quote for S3 storage + outbound transfer and persists it.
3. **Upload**: Client encrypts the backup, settles payment (USDC on Base, onchain or mock), and stores ciphertext in a wallet-scoped S3 bucket.
4. **Ls**: Backend returns object size and bucket metadata.
5. **Download**: Proxy fetches the encrypted object from S3 via a presigned URL and writes it to local disk.
6. **Hash match**: Local tooling confirms that the downloaded ciphertext matches what was uploaded (integrity).

Each step is documented in more detail in the existing process-flow specs under `meta_docs/`.

## References

- Backup: `meta_docs/cloud-backup-process-flow.md`  
- Quote: `meta_docs/cloud-price-storage-process-flow.md`  
- Upload: `meta_docs/cloud-upload-process-flow.md`  
- List: `meta_docs/cloud-ls-process-flow.md`  
- Download: `meta_docs/cloud-download-process-flow.md`  
- Delete: `meta_docs/cloud-delete-process-flow.md`  
- Wallet proof auth: `meta_docs/wallet-proof.md`  
- Payment auth (x402): `meta_docs/payment-authorization-eip712-trace.md`

Raw GitHub URLs for automated agents:

- Backup: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cloud-backup-process-flow.md`
- Price-storage: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cloud-price-storage-process-flow.md`
- Upload: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cloud-upload-process-flow.md`
- Ls: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cloud-ls-process-flow.md`
- Download: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cloud-download-process-flow.md`
- Delete: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cloud-delete-process-flow.md`
- Wallet proof: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/wallet-proof.md`
- Payment auth: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/payment-authorization-eip712-trace.md`

## High-level sequence

```mermaid
sequenceDiagram
    participant User
    participant Client as Client<br/>(mnemospark)
    participant Proxy as Local Proxy<br/>(127.0.0.1:7120)
    participant APIGW as API Gateway
    participant Auth as WalletAuthorizer
    participant Price as PriceStorage
    participant Upload as StorageUpload
    participant Ls as StorageLs
    participant Download as StorageDownload
    participant S3 as S3

    User->>Client: /mnemospark-cloud backup <path>
    Client->>Client: Build archive, write object.log

    User->>Client: /mnemospark-cloud price-storage ...
    Client->>Proxy: POST /mnemospark/price-storage
    Proxy->>APIGW: POST /price-storage (+X-Wallet-Signature optional)
    APIGW->>Price: Invoke Lambda
    Price-->>APIGW: 200 quote_id, storage_price, ...
    APIGW-->>Proxy: 200
    Proxy-->>Client: 200
    Client->>Client: Append quote to object.log

    User->>Client: /mnemospark-cloud upload ...
    Client->>Client: Verify archive, encrypt, resolve wallet, set up x402
    Client->>Proxy: POST /mnemospark/upload (+payment headers on retry)
    Proxy->>APIGW: POST /storage/upload (+X-Wallet-Signature)
    APIGW->>Auth: Verify wallet proof
    Auth-->>APIGW: Allow
    APIGW->>Upload: Invoke Lambda
    Upload->>S3: PutObject or generate_presigned_url
    Upload-->>APIGW: 200 (or 207/presigned-flow)
    APIGW-->>Proxy: Response
    Proxy-->>Client: Response
    Client->>Client: Handle payment + S3 result, write object.log + crontab.txt

    User->>Client: /mnemospark-cloud ls ...
    Client->>Proxy: POST /mnemospark/storage/ls
    Proxy->>APIGW: POST /storage/ls (+X-Wallet-Signature)
    APIGW->>Auth: Authorize
    Auth-->>APIGW: Allow
    APIGW->>Ls: Invoke Lambda
    Ls->>S3: head_bucket + head_object
    Ls-->>APIGW: 200 metadata
    APIGW-->>Proxy: 200
    Proxy-->>Client: 200

    User->>Client: /mnemospark-cloud download ...
    Client->>Proxy: POST /mnemospark/storage/download
    Proxy->>APIGW: POST /storage/download (+X-Wallet-Signature)
    APIGW->>Auth: Authorize
    Auth-->>APIGW: Allow
    APIGW->>Download: Invoke Lambda
    Download->>S3: generate_presigned_url(get_object)
    Download-->>APIGW: 200 download_url
    APIGW-->>Proxy: 200
    Proxy->>S3: GET download_url
    S3-->>Proxy: Ciphertext bytes
    Proxy-->>Client: 200 { file_path, bytes_written }
    User->>User: Compare local hash of ciphertext<br/>with original object-id-hash
```

This diagram is descriptive of the milestone behavior rather than prescriptive; see the individual flow docs for full parameter and error-handling details.

