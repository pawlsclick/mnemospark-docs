# Cursor Dev: IAM and Config for Price List–based /price-storage

**ID:** fix-02-price-list-iam-and-config  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. It contains the AWS SAM template, Lambda functions (including `/price-storage`), and tests for the mnemospark backend. Do **not** clone, or require access to any other repository; all code and references are in this file. References: see **References** section below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Adjust IAM and configuration for the `PriceStorageFunction` so that it has the correct, least-privilege permissions for the new AWS Price List Query API–based implementation, and no longer carries unused BCM Pricing Calculator permissions, while preserving all existing DynamoDB and API Gateway behavior.

This fix **depends on** `fix-01-price-list-price-storage-lambda` having already refactored the `/price-storage` Lambda to use the AWS Pricing (Price List Query) API.

Concretely in `template.yaml`:

- Update the `PriceStorageLambdaRole` resource:
  - Ensure it grants the minimal actions required to call the AWS Price List Query API from the `/price-storage` Lambda, for example:
    - `pricing:DescribeServices`
    - `pricing:GetProducts`
    - If the refactored code uses it, `pricing:GetAttributeValues`
  - Keep the existing DynamoDB permissions needed to write/read quotes in `QuotesTable`:
    - `dynamodb:DescribeTable`
    - `dynamodb:GetItem`
    - `dynamodb:PutItem`
    - `dynamodb:UpdateItem`
  - Confirm that any **BCM Pricing Calculator–specific permissions** under this role (e.g. `bcm-pricing-calculator:CreateWorkloadEstimate`, `GetWorkloadEstimate`, `DeleteWorkloadEstimate`, `CreateWorkloadEstimateUsage`, and `sts:GetCallerIdentity` attached solely for BCM) are no longer required by `/price-storage` and can be safely removed or reduced.

- Validate that no other Lambda functions rely on BCM-specific permissions provided by `PriceStorageLambdaRole`:
  - If any shared IAM policies are reused by other functions that still depend on BCM (e.g., for legacy or other features), do **not** remove required permissions for those functions.
  - If `/price-storage` is the only remaining consumer, it should be safe to remove the BCM permissions from `PriceStorageLambdaRole`.

- Confirm `PriceStorageFunction` environment variables and configuration remain consistent:
  - Keep `QUOTES_TABLE_NAME`, `QUOTE_TTL_SECONDS`, and markup-related env vars (`PRICE_STORAGE_MARKUP_PERCENT` or `PRICE_MARKUP_PERCENT`), since the new pricing logic still uses them.
  - If the new implementation no longer uses `PRICE_STORAGE_RATE_TYPE` or `PRICE_STORAGE_TRANSFER_DIRECTION` (because rate-type and direction are now expressed directly via Price List SKU selection), either:
    - Keep them for backward compatibility but clearly unused (acceptable if they are harmless), or
    - Remove or repurpose them, updating code and tests accordingly (if this has already been done in `fix-01`, ensure Template and code match).

- After edits:
  - Run `sam validate` to ensure the template is syntactically valid.
  - Optionally run a local or staging deployment (depending on the environment) to confirm `/price-storage` runs correctly under the updated IAM role.

## References

- High-level documentation for the `/price-storage` flow:
  - [mnemospark-docs/meta_docs/cloud-price-storage-process-flow.md](../../../mnemospark-docs/meta_docs/cloud-price-storage-process-flow.md)
- Backend API template and function definitions:
  - [mnemospark-backend/template.yaml](../../../mnemospark-backend/template.yaml)
- `/price-storage` Lambda implementation (after `fix-01` has been applied):
  - [mnemospark-backend/services/price-storage/app.py](../../../mnemospark-backend/services/price-storage/app.py)
  - [mnemospark-backend/services/price_storage_entry.py](../../../mnemospark-backend/services/price_storage_entry.py)
- Quotes table and related resources:
  - `QuotesTable` definition and references in [mnemospark-backend/template.yaml](../../../mnemospark-backend/template.yaml)
- Existing IAM role for price-storage (to be updated by this fix):
  - `PriceStorageLambdaRole` in [mnemospark-backend/template.yaml](../../../mnemospark-backend/template.yaml)
- Context about the existing BCM-based estimate functions (for understanding what is being phased out, not modified in this fix):
  - [mnemospark-backend/services/estimate-storage/app.py](../../../mnemospark-backend/services/estimate-storage/app.py)
  - [mnemospark-backend/services/estimate-transfer/app.py](../../../mnemospark-backend/services/estimate-transfer/app.py)
- AWS documentation for Pricing / Price List Query and IAM:
  - [Finding services and products using AWS Price List Query API](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/using-price-list-query-api.html)
  - AWS IAM documentation for the `pricing` service (accessible via AWS MCP `aws___read_documentation` / `aws___call_aws` tools).

## Agent

- **Install (idempotent):**  
  `pip install -r requirements.txt`

- **Start (if needed):**  
  None.

- **Secrets:**  
  None required for editing IAM and configuration. If you run a deployment or live test, AWS credentials will be needed in the environment (e.g., `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`), but they are not required to update the template and run `sam validate`.

- **Acceptance criteria (checkboxes):**
  - [ ] `PriceStorageLambdaRole` in `template.yaml` explicitly grants the AWS Pricing/Price List Query API actions required by the refactored `/price-storage` Lambda (e.g. `pricing:DescribeServices`, `pricing:GetProducts`, and `pricing:GetAttributeValues` if used).
  - [ ] `PriceStorageLambdaRole` retains the necessary DynamoDB permissions for the quotes table and does not remove any permissions still required by other functions.
  - [ ] BCM Pricing Calculator–specific permissions that are no longer needed by `/price-storage` are removed or reduced from `PriceStorageLambdaRole`, without breaking any remaining functionality.
  - [ ] `sam validate` passes successfully after the IAM changes.
  - [ ] A test invocation of `/price-storage` against a staging or test stack succeeds under the updated IAM role (assuming environment supports running such a test).

## Task string (optional)

Work only in the `mnemospark-backend` repo. Update the CloudFormation/SAM template (`template.yaml`) so that the `PriceStorageLambdaRole` used by `PriceStorageFunction` has the minimum required permissions to call the AWS Pricing (Price List Query) API and to read/write quotes in DynamoDB, and no longer includes BCM Pricing Calculator–specific permissions that the new `/price-storage` implementation no longer uses. Keep all non-pricing-related resources and behavior intact, run `sam validate` to confirm template correctness, and ensure `/price-storage` continues to function correctly with the updated IAM configuration. This fix depends on `fix-01-price-list-price-storage-lambda` and should not modify the Lambda code itself beyond what is required to keep configuration consistent.

