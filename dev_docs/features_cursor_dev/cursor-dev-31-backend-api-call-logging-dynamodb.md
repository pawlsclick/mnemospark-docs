# Cursor Dev: API call logging to DynamoDB

**ID:** cursor-dev-31  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. It contains the Lambda handlers, SAM template, and backend docs. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Introduce a shared **DynamoDB-based API call logging** mechanism that records key metadata for every backend API invocation, across all wallet-scoped endpoints.

In more detail:

- Add a new **DynamoDB table** (e.g. `${StackName}-api-calls`) in `template.yaml`:
  - PAY_PER_REQUEST billing.
  - Simple primary key (e.g. `request_id` as `HASH`) and, optionally, a `route` or `operation` `RANGE` to support analysis.
  - Consider a TTL attribute for aging out old records.
- Implement a **small shared Python module** (e.g. `services/common/api_call_logger.py`) that exposes a function like `log_api_call(event, context, route, result, **extra)` which:
  - Extracts:
    - API Gateway request ID.
    - HTTP method and normalized path.
    - Wallet address from the authorizer context (if present).
    - Status code and error code / message (as passed in from the handler).
    - Any relevant IDs (e.g. `quote_id`, `trans_id`, `payment_id`).
  - Writes an item to the `api-calls` table with this metadata.
  - Emits a structured JSON log line to CloudWatch with the same fields.
  - Swallows or degrades gracefully on write failures (no impact to the primary handler behavior).
- Integrate this logging helper into the following Lambda handlers:
  - `services/price-storage/app.py` (`lambda_handler`).
  - `services/storage-upload/app.py` (`lambda_handler` and `confirm_upload_handler`).
  - `services/storage-ls/app.py`.
  - `services/storage-download/app.py`.
  - `services/storage-delete/app.py`.
- For each handler, ensure:
  - Successful responses and major failure paths (4xx/5xx) invoke the logging helper with:
    - Final HTTP status code.
    - A short `result` string (e.g. `success`, `bad_request`, `forbidden`, `not_found`, `internal_error`).
    - A compact error code string where appropriate (e.g. `quote_not_found`, `payment_required`, `wallet_mismatch`).
- Update IAM in `template.yaml` so each relevant Lambda role has least-privilege access to the `api-calls` table.

Depends on cursor-dev-29 (Backend OAS 3.2 skeleton and endpoint inventory) for the canonical list of routes, and cursor-dev-30 (Wallet proof enforcement and authorizer logging) for the final auth context shape.

## References

- `template.yaml` (Lambda function definitions and IAM roles).
- `services/price-storage/app.py` (pricing quote flow).
- `services/storage-upload/app.py` (upload and confirm handlers, existing transaction log).
- `services/storage-ls/app.py`, `services/storage-download/app.py`, `services/storage-delete/app.py`.
- `dev_docs/features_cursor_dev/cursor-dev-29-backend-oas-skeleton-and-inventory.md`.
- `dev_docs/features_cursor_dev/cursor-dev-30-backend-wallet-proof-enforcement-and-auth-logging.md`.

## Agent

- **Install (idempotent):** `pip install -r requirements.txt || true`
- **Start (if needed):** None.
- **Secrets:** None (use local SAM/lint/test only; no live AWS calls are required beyond local testing).
- **Acceptance criteria (checkboxes):**
  - [ ] A new `api-calls` DynamoDB table is defined in `template.yaml` with PAY_PER_REQUEST billing and an appropriate key schema.
  - [ ] A shared logging module exists and can be imported by all relevant Lambdas.
  - [ ] Each targeted handler (`price-storage`, `storage-upload` + confirm, `storage-ls`, `storage-download`, `storage-delete`) calls the helper on both success and major failure paths.
  - [ ] The logged items contain method, normalized path, wallet address (when available), status code, and a result/error code.
  - [ ] IAM policies for each Lambda role allow writes to `api-calls` with least privilege.

## Task string (optional)

Work only in the `mnemospark-backend` repo. Add a new DynamoDB `api-calls` table and a shared Python helper that logs structured API call metadata both to DynamoDB and CloudWatch for all public endpoints. Wire this helper into `price-storage`, `storage-upload` (and confirm), `storage-ls`, `storage-download`, and `storage-delete`, ensuring that both success and failure cases are recorded without impacting primary behavior if logging fails. Acceptance: [ ] table and IAM defined, [ ] helper shared, [ ] all handlers log calls with method, path, wallet, status, and result/error code.

