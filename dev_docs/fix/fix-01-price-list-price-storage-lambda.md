# Cursor Dev: Price List–based /price-storage Lambda

**ID:** fix-01-price-list-price-storage-lambda  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. It contains the mnemospark backend AWS SAM template, Lambda handlers (including `/price-storage`), and associated tests and infrastructure. Do **not** clone, or require access to any other repository; all code and references are in this file. References: see **References** section below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Implement a new **AWS Price List Query API–based** implementation of the `/price-storage` Lambda, replacing the internal use of the BCM Pricing Calculator while preserving the current external request/response contract and DynamoDB quote semantics.

Concretely:

- Update the `PriceStorageFunction` implementation in this repo so that the backend uses the AWS **Pricing** (Price List Query) API to calculate the quote instead of the BCM Pricing Calculator helpers:
  - Keep the HTTP interface and validation exactly the same as today: `POST /price-storage` with JSON body containing `wallet_address`, `object_id`, `object_id_hash`, `gb`, `provider`, `region`.
  - Keep the **region semantics the same** as today: `region` is an AWS region string such as `us-east-1`. Use this value to filter Price List products correctly (e.g. via `regionCode`, `locationType = AWS Region`, or other documented attributes).
  - Preserve the current 400/500 error behavior: invalid input should still result in `{"error": "Bad request", "message": ...}` and pricing/DynamoDB failures should still surface as `{"error": "Internal error", "message": ...}`.

- In `services/price-storage/app.py` (and `services/price_storage_entry.py` if needed):
  - Leave `parse_input`, wallet/authorizer context extraction, markup/TTL env handling, DynamoDB write logic (`write_quote`), and response building (`_build_quote_response`) intact, unless changes are required to support the new pricing helpers.
  - Replace the current use of dynamically-loaded BCM-based helpers:
    - `_ESTIMATE_STORAGE_MODULE = _load_service_module("price_storage_estimate_storage", "estimate-storage")`
    - `_ESTIMATE_TRANSFER_MODULE = _load_service_module("price_storage_estimate_transfer", "estimate-transfer")`
    - `estimate_storage_cost(...)` / `estimate_transfer_cost(...)` that call `estimate_s3_storage_cost` and `estimate_data_transfer_cost`
    with **new internal pricing helpers** that use the AWS Price List Query API, for example:
    - `get_s3_storage_price_per_gb_month(region: str, client: boto3.client | None = None) -> float`
    - `get_data_transfer_out_price_per_gb(region: str, client: boto3.client | None = None) -> float`
  - Implement these helpers using the AWS Pricing/Price List Query API:
    - Prefer using the AWS SDK (`boto3.client("pricing")`) or the AWS MCP `aws___call_aws` tool to retrieve price list data.
    - For storage pricing:
      - Use `serviceCode = "AmazonS3"` and filter attributes to select **S3 Standard** storage in the requested region (e.g. via `locationType`, `location`, `regionCode`, `productFamily`, and S3-specific attributes such as `volumeType` / `storageClass` depending on what the Price List API exposes).
      - Parse the resulting `terms` (OnDemand or Savings Plan as appropriate; OnDemand is likely simplest) to derive a **price per GB-month** in the correct currency.
    - For data transfer pricing:
      - Use `serviceCode = "AmazonEC2"` (or whichever service exposes the data-transfer SKUs) and filter attributes to select **data transfer out to internet** for the requested region (commonly `usagetype` containing `DataTransfer-Out-Bytes` plus a region suffix, and region attributes similar to S3).
      - Parse terms to derive a **price per GB** for outbound data transfer.
    - The implementation may need to:
      - Use `DescribeServices`/`GetAttributeValues` to discover valid attributes if needed.
      - Handle pagination and multiple matching products safely, selecting the most appropriate SKU (e.g. lowest OnDemand rate for the specified region and usage type).

- Once per-unit prices are available:
  - Compute the unmarked costs:
    - `storage_cost = price_per_gb_month * gb`
    - `transfer_cost = price_per_gb_out * gb`
  - Compute the final quote price using the existing markup logic:
    - `storage_price = round((storage_cost + transfer_cost) * (1 + markup_multiplier), 2)`
    - `markup_multiplier` continues to come from `PRICE_STORAGE_MARKUP_PERCENT` / `PRICE_MARKUP_PERCENT` env vars, using the same parsing rules as today.
  - Continue to build the quote object and persist it to DynamoDB as before (same attributes, same TTL rules).

- Ensure the **response JSON shape** remains exactly the same as documented in `cloud-price-storage-process-flow.md`:
  - `timestamp`, `quote_id`, `storage_price`, `addr`, `object_id`, `object_id_hash`, `object_size_gb`, `provider`, `location`.

- Update or extend **unit tests** for `PriceStorageFunction` (e.g. in `tests/unit/test_price_storage.py` and `tests/integration/test_price_storage_integration.py`):
  - Mock the AWS Pricing API client so that unit tests do not require live AWS calls.
  - Verify that for a given mocked storage and transfer per-unit price, the handler computes `storage_price` correctly, respecting the markup and rounding rules.
  - Ensure error conditions (invalid input, pricing failures, missing SKUs) behave as expected (400 for bad request, 500 for internal errors).

## References

- High-level process for `/mnemospark-cloud price-storage`:
  - [mnemospark-docs/meta_docs/cloud-price-storage-process-flow.md](../../../mnemospark-docs/meta_docs/cloud-price-storage-process-flow.md)
- Backend API base URL and how the client/proxy talks to this backend:
  - [mnemospark-docs/meta_docs/backend-api-base-url.md](../../../mnemospark-docs/meta_docs/backend-api-base-url.md)
- Wallet proof behavior (context for optional authorizer on `/price-storage`):
  - [mnemospark-docs/meta_docs/wallet-proof.md](../../../mnemospark-docs/meta_docs/wallet-proof.md)
- Full CloudFormation/SAM definition of the backend, including `PriceStorageFunction` and quotes table:
  - [mnemospark-backend/template.yaml](../../../mnemospark-backend/template.yaml)
- Current `/price-storage` Lambda implementation (to be refactored):
  - [mnemospark-backend/services/price-storage/app.py](../../../mnemospark-backend/services/price-storage/app.py)
  - [mnemospark-backend/services/price_storage_entry.py](../../../mnemospark-backend/services/price_storage_entry.py)
- Existing BCM-based helpers (for understanding the current behavior; these will no longer be used by `/price-storage` after this fix):
  - [mnemospark-backend/services/estimate-storage/app.py](../../../mnemospark-backend/services/estimate-storage/app.py)
  - [mnemospark-backend/services/estimate-transfer/app.py](../../../mnemospark-backend/services/estimate-transfer/app.py)
- Tests that exercise pricing behavior:
  - [mnemospark-backend/tests/unit/test_price_storage.py](../../../mnemospark-backend/tests/unit/test_price_storage.py)
  - [mnemospark-backend/tests/integration/test_price_storage_integration.py](../../../mnemospark-backend/tests/integration/test_price_storage_integration.py)
- Client/proxy side that must remain compatible (for context only; do not modify these repos in this run):
  - [mnemospark/src/cloud-command.ts](../../../mnemospark/src/cloud-command.ts)
  - [mnemospark/src/cloud-price-storage.ts](../../../mnemospark/src/cloud-price-storage.ts)
  - [mnemospark/src/proxy.ts](../../../mnemospark/src/proxy.ts)
- AWS documentation for Price List Query API and Pricing:
  - [Finding services and products using AWS Price List Query API](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/using-price-list-query-api.html)
  - AWS Pricing API reference via AWS MCP `aws___read_documentation` / `aws___call_aws` tools as needed.

## Agent

- **Install (idempotent):**  
  `pip install -r requirements.txt`

- **Start (if needed):**  
  None.

- **Secrets:**  
  - For unit tests with mocked Pricing clients: None.  
  - For any optional live integration tests against AWS Pricing: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`.

- **Acceptance criteria (checkboxes):**
  - [ ] `POST /price-storage` still accepts the same JSON request schema (`wallet_address`, `object_id`, `object_id_hash`, `gb`, `provider`, `region`) and returns the same response fields as documented in `cloud-price-storage-process-flow.md`.
  - [ ] The `/price-storage` Lambda no longer depends on the BCM Pricing Calculator helpers from `services/estimate-storage` and `services/estimate-transfer`; instead, it uses the AWS Price List Query API (Pricing service) to compute S3 storage and outbound data transfer prices.
  - [ ] For a given mocked storage and transfer per-unit price, the Lambda computes `storage_price = round((storage_cost + transfer_cost) * (1 + markup_multiplier), 2)` and persists the quote to DynamoDB with the same attributes and TTL behavior as before.
  - [ ] Invalid input (e.g. `gb <= 0`, missing required fields, unsupported provider) still returns a 400 response with a clear `{"error": "Bad request", "message": ...}` body.
  - [ ] AWS Pricing API failures (e.g. no matching product, API error) result in a 500 `{"error": "Internal error", "message": ...}` response while leaving DynamoDB unchanged.
  - [ ] Unit and integration tests for `price-storage` pass, with new tests added or existing tests updated to cover the Price List–based implementation.

## Task string (optional)

Work only in the `mnemospark-backend` repo. Refactor the `/price-storage` Lambda implementation in `services/price-storage/app.py` so that it uses the AWS Price List Query API (Pricing service) to compute S3 Standard storage and outbound data transfer prices for the requested region and GB amount, instead of using the existing BCM Pricing Calculator helpers from `estimate-storage` and `estimate-transfer`. Preserve the existing HTTP contract, region semantics, markup and rounding logic, and DynamoDB quote persistence (including quote structure and TTL). Update or add unit and integration tests so that the new behavior is fully covered and all tests pass.

