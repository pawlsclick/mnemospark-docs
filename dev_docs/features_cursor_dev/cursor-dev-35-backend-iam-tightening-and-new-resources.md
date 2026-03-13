# Cursor Dev: Backend IAM tightening and new resources

**ID:** cursor-dev-35  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. It defines all Lambda roles and permissions in `template.yaml`. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS IAM, Lambda, and DynamoDB permissions.

## Scope

Ensure IAM role permissions are **accurate and least-privilege** for all AWS services and API endpoint actions, including new resources introduced in previous tasks (`wallet-auth-events`, `api-calls`, payment ledger, `/payment/settle` Lambda).

In more detail:

- In `template.yaml`:
  - Review existing IAM roles:
    - `PriceStorageLambdaRole`
    - `UploadLambdaRole`
    - Any roles attached to `StorageLsFunction`, `StorageDownloadFunction`, `StorageDeleteFunction`.
    - Any role used by the wallet authorizer.
  - Add or refine IAM policies for:
    - The **wallet authorizer** to write to the `wallet-auth-events` table (cursor-dev-30).
    - All public-facing Lambdas to write to the `api-calls` table (cursor-dev-31).
    - The new `/payment/settle` Lambda to:
      - Read from `QuotesTable` (if needed).
      - Write to the payment ledger table.
      - Use Secrets Manager and Base RPC endpoints only as required.
  - Remove or narrow any broad permissions (e.g. wildcards) where possible without breaking functionality, especially:
    - DynamoDB actions.
    - S3 actions (ensure only `mnemospark-*` resources are referenced).
    - Secrets Manager access for the relayer key.
- Use AWS documentation (via AWS MCP) as needed to:
  - Confirm minimal action sets for:
    - DynamoDB read/write patterns used by each Lambda.
    - S3 operations used by storage Lambdas and housekeeping.
    - CloudWatch logging where relevant.
- Ensure that:
  - Logging and housekeeping Lambdas have the S3 and DynamoDB permissions they need, but no more.
  - CloudTrail and CloudWatch-related resources remain correctly configured and functional.

Depends on:
- cursor-dev-30 (Wallet proof enforcement and authorizer logging).
- cursor-dev-31 (API call logging to DynamoDB).
- cursor-dev-32 (Payment settlement endpoint).
- cursor-dev-33 (Storage upload requires prior payment record).
- cursor-dev-34 (Logging and housekeeping alignment).

## References

- `template.yaml` (all IAM roles and resource policies).
- `services/*/app.py` as needed to infer which AWS actions each Lambda actually uses.
- `dev_docs/features_cursor_dev/cursor-dev-30-backend-wallet-proof-enforcement-and-auth-logging.md`.
- `dev_docs/features_cursor_dev/cursor-dev-31-backend-api-call-logging-dynamodb.md`.
- `dev_docs/features_cursor_dev/cursor-dev-32-backend-payment-settle-endpoint.md`.
- `dev_docs/features_cursor_dev/cursor-dev-33-backend-storage-upload-require-payment-record.md`.
- `dev_docs/features_cursor_dev/cursor-dev-34-backend-logging-and-housekeeping-alignment.md`.

## Agent

- **Install (idempotent):** `pip install -r requirements.txt || true`
- **Start (if needed):** None.
- **Secrets:** None (use specification and static analysis; do not require live AWS credentials).
- **Acceptance criteria (checkboxes):**
  - [ ] All new tables and Lambdas (`wallet-auth-events`, `api-calls`, payment ledger, `/payment/settle`) have explicit IAM policies granting only the actions they need.
  - [ ] Existing roles for pricing, upload, storage operations, housekeeping, and the authorizer are reviewed and narrowed where feasible.
  - [ ] No Lambda role has write access to DynamoDB or S3 resources it does not use.
  - [ ] CloudWatch and CloudTrail logging-related roles remain functional.

## Task string (optional)

Work only in the `mnemospark-backend` repo. Review and update IAM roles and inline policies in `template.yaml` so that all Lambdas (including the new payment and logging-related code) have least-privilege access to DynamoDB, S3, Secrets Manager, and CloudWatch, and that new tables like `wallet-auth-events`, `api-calls`, and the payment ledger are properly permissioned. Acceptance: [ ] new resources have correct IAM, [ ] existing roles are tightened without breaking documented functionality.

