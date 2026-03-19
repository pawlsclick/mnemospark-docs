# Test onchain upload in staging

## Purpose

Staging is deployed with payment settlement **onchain** on **Base mainnet** (RPC `https://mainnet.base.org`, Chain ID 8453). This doc describes how to test the upload flow and verify a real Base transaction so that `trans_id` in the response is a real TxHash (viewable on BaseScan).

## Wallets

### Recipient wallet (in code)

**Address:** `0x47D241ae97fE37186AC59894290CA1c54c060A6c`

USDC payments from users go to this address when the relayer submits `transferWithAuthorization`. It is defined in mnemospark-backend as the template parameter `MnemosparkRecipientWallet` (default) and in `services/storage-upload/app.py` as `DEFAULT_RECIPIENT_WALLET`; the upload Lambda receives it as `MNEMOSPARK_RECIPIENT_WALLET`.

### Relayer wallet (not in code)

The **relayer** is the wallet that signs and submits the Base transaction and pays gas. Its **private key** is stored in AWS Secrets Manager (`mnemospark/relayer-private-key`). The Lambda derives the relayer **address** at runtime from that key; the public address is not in the codebase.

This wallet must hold **ETH on Base mainnet** to pay gas. Operators can derive the relayer address from the secret (e.g. with `eth-account`) or from the first successful upload tx on BaseScan, and optionally record it here (e.g. "Staging relayer address: 0x…") for funding and verification.

### Relayer and recipient can be the same

There is no requirement that they differ. The same wallet can submit the transaction (and pay gas) and receive USDC: use that wallet’s private key in the secret and set the recipient to the same address (or use the default recipient if it is that wallet). Using one wallet for both is valid and simplifies setup (one key, one address to fund with ETH and receive USDC). Using two wallets is optional for operational separation (e.g. hot relayer vs. cold/multisig recipient).

## Prerequisites

Before testing onchain upload in staging:

1. **Relayer secret in AWS Secrets Manager (staging account)**  
   Secret name: `mnemospark/relayer-private-key`. Value: the relayer wallet’s **private key**. Same account and region as the staging stack. The upload Lambda role already has `secretsmanager:GetSecretValue` on this secret.

2. **Relayer funded with ETH on Base mainnet**  
   The address derived from the key in the secret must have enough **ETH on Base mainnet** to pay gas for `transferWithAuthorization`. USDC is transferred user → recipient; gas is paid by the relayer.

3. **Staging deployed with onchain + mainnet**  
   Staging must be deployed with `PaymentSettlementMode=onchain` and `BaseRpcUrl=https://mainnet.base.org`. This is handled by the mnemospark-backend repo when using branch `chore/going-onchain` (samconfig.staging.toml); after that is merged to `main`, the Deploy Staging workflow will deploy with these parameters.

## How to test

1. From OpenClaw (or a host with mnemospark configured to use the staging API), run **`/mnemospark_cloud upload`** (or the equivalent `mnemospark_cloud` command) so the request hits the staging API and goes through: quote → payment auth → upload → onchain settlement.

2. In the upload response, read **`trans_id`**. It must be a `0x`-prefixed string of 64 hex characters (a real transaction hash).

3. Open **BaseScan** (mainnet: https://basescan.org) and look up that `trans_id`. It should show the USDC `transferWithAuthorization` transaction.

4. If something fails, check **CloudWatch** logs for the upload Lambda (StorageUploadFunction) in the mnemospark-staging stack.

## Reference

- [trans_id and payment settlement (mock vs onchain)](../meta_docs/trans-id-payment-settement.md) — what `trans_id` represents and how mock vs onchain mode differ.
