# `quote_id` in DynamoDB (mnemospark quotes)

**Date:** 2026-03-16  
**Revision:** rev 1  
**Milestone:** e2e-staging-2026-03-16 (mnemospark-backend)  
**Repos / components:** mnemospark-backend (price-storage, quotes table)

## What `quote_id` represents

`quote_id` is the identifier for a **1-hour storage quote** created by `POST /price-storage`.

The quote is persisted in a DynamoDB **Quotes** table so that `POST /storage/upload` can later:

- Look up the quote by `quote_id`
- Validate the quoted terms (wallet, object hash, amount, etc.)
- Settle payment and complete the upload

## DynamoDB type and keying

In the quotes table, `quote_id` is:

- **Data type:** DynamoDB **String** (`S`)
- **Primary key:** Partition key (`HASH`) named `quote_id`

This means DynamoDB can only store **one item per `quote_id`**.

## How `quote_id` is generated

The price-storage Lambda generates `quote_id` as a **UUID v4** string:

- `quote_id = str(uuid.uuid4())`

It is not sequential and does not “increment.”

## Uniqueness guarantees

`quote_id` is unique in practice and protected in two ways:

- **UUID v4 randomness:** collision probability is negligible at real-world volumes.
- **Conditional write:** the quote write uses a condition equivalent to “only insert if this `quote_id` does not already exist”:
  - `ConditionExpression = "attribute_not_exists(quote_id)"`

If a collision ever occurred, the second write would fail rather than overwrite.

## TTL / expiration behavior (quotes)

Quotes are stored with an `expires_at` field (epoch seconds) computed as:

- `expires_at = now + QUOTE_TTL_SECONDS`

The table is intended for short-lived quotes (default 1 hour) so old quotes age out automatically.

---

## Spec references

- This doc: `meta_docs/quote-id-dynamodb.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/quote-id-dynamodb.md`
- Price-storage flow: `meta_docs/cloud-price-storage-process-flow.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cloud-price-storage-process-flow.md`
- Upload flow: `meta_docs/cloud-upload-process-flow.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cloud-upload-process-flow.md`
- Milestone overview: `meta_docs/e2e-staging-milestone-2026-03-16.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/e2e-staging-milestone-2026-03-16.md`

