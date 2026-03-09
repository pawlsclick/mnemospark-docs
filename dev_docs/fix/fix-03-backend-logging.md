# Cursor Dev: Add Structured Logging to Storage Upload Lambda

**ID:** fix-03  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. This repo is a serverless AWS Lambda backend (Python 3.13) using AWS SAM. The storage upload Lambda lives at `services/storage-upload/app.py`. Do **not** clone, or require access to any other repository; all code and references are in this file References.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Add **structured logging** to `services/storage-upload/app.py`. The handler currently has zero `print()`, `logging.info()`, or `logger.xxx()` calls across 1231 lines. All observability comes from Lambda runtime auto-logging (only unhandled exceptions) and API Gateway access logs (request metadata only). This makes diagnosing payment and storage failures in production nearly impossible.

**Changes required:**

1. **Initialize logger** at module level (near the top of the file, after imports):
   ```python
   import logging

   logger = logging.getLogger(__name__)
   logger.setLevel(logging.INFO)
   ```

2. **Add log statements** at the following decision points in `lambda_handler()` (line 1086) and its helper functions:

   | Location | Log Level | What to Log |
   |---|---|---|
   | After `parse_input()` succeeds (line 1095) | INFO | `quote_id`, `wallet_address`, `object_id`, `mode` (if present) |
   | After `_require_authorized_wallet()` (line 1096) | DEBUG | Authorized wallet confirmed |
   | Idempotency cache hit (line 1112) | INFO | `idempotency_key`, "returning cached response" |
   | Idempotency lock claimed (line 1133) | INFO | `idempotency_key`, "lock acquired" |
   | Quote lookup result -- after `_build_quote_context()` (line 1119) | INFO | `quote_id`, `storage_price`, `storage_price_micro`, `provider`, `location` |
   | Payment verification success -- after `verify_and_settle_payment()` (line 1135) | INFO | `trans_id`, `settlement_mode`, `amount`, `network` |
   | S3 upload success -- after `_upload_ciphertext_to_s3()` (line 1146) | INFO | `bucket_name`, `object_key`, `ciphertext` size in bytes |
   | Presigned URL generated (if fix-02 is applied) | INFO | `bucket_name`, `object_key`, "presigned URL generated" |
   | Transaction log written (line 1154) | INFO | `trans_id`, `quote_id` |
   | Quote deleted (line 1165) | DEBUG | `quote_id`, "consumed quote deleted" |
   | Idempotency marked completed (line 1191) | DEBUG | `idempotency_key` |
   | Each `except` handler (lines 1203-1230) | WARNING or ERROR | Error type, message, `quote_id` and `wallet_address` if available |

3. **Log format**: Use structured key-value pairs for easy CloudWatch Insights querying:
   ```python
   logger.info(
       "upload_request_parsed",
       extra={
           "quote_id": request.quote_id,
           "wallet_address": request.wallet_address,
           "object_id": request.object_id,
       },
   )
   ```
   
   Alternatively, use JSON-formatted messages that CloudWatch can parse:
   ```python
   logger.info(json.dumps({
       "event": "upload_request_parsed",
       "quote_id": request.quote_id,
       "wallet_address": request.wallet_address,
       "object_id": request.object_id,
   }))
   ```

4. **Do NOT log sensitive data**: Do not log `ciphertext` content, `wrapped_dek` values, payment signatures, or wallet private keys. Only log identifiers, sizes, and status information.

5. **Do NOT change any functional behavior**: This fix adds only logging. No control flow, return values, or error handling should change.

## References

- `services/storage-upload/app.py` -- `lambda_handler()` (line 1086), `parse_input()` (line 399), `verify_and_settle_payment()` (line 791), `_upload_ciphertext_to_s3()` (line 1025), `_write_transaction_log()` (line 1045), error handlers (lines 1203-1230)
- `template.yaml` -- `StorageUploadFunctionLogGroup` (lines 811-818), `ObservabilityLogRetentionDays` parameter
- AWS Lambda Python logging best practices: https://docs.aws.amazon.com/lambda/latest/dg/python-logging.html

## Agent

- **Install (idempotent):** `source /workspace/.venv/bin/activate && pip install -r services/storage-upload/requirements.txt`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] A `logger` is initialized at module level using `logging.getLogger(__name__)`
  - [ ] INFO-level log at request parsing success with `quote_id`, `wallet_address`, `object_id`
  - [ ] INFO-level log at quote lookup with `quote_id`, `storage_price`, `provider`, `location`
  - [ ] INFO-level log at payment verification success with `trans_id`, settlement mode, `amount`
  - [ ] INFO-level log at S3 upload success with `bucket_name`, `object_key`, ciphertext size
  - [ ] INFO-level log at idempotency cache hit and lock acquisition
  - [ ] WARNING/ERROR-level logs in each `except` handler with error context
  - [ ] No sensitive data logged (no ciphertext content, no keys, no payment signatures)
  - [ ] No functional behavior changed -- only logging added
  - [ ] Lint passes: `ruff check services/storage-upload/`
  - [ ] Tests pass: `pytest tests/ -v`
  - [ ] The agent creates a new branch, commits, and opens a PR

## Task string (optional)

Work only in this repo (mnemospark-backend). In `services/storage-upload/app.py`, add structured logging using `logging.getLogger(__name__)`. Add INFO-level logs at: request parsing, quote lookup, payment verification, S3 upload, idempotency events. Add WARNING/ERROR logs in each except handler. Use JSON-formatted messages for CloudWatch Insights. Do NOT log sensitive data (ciphertext, keys, signatures). Do NOT change any functional behavior. Run `ruff check services/storage-upload/` and `pytest tests/ -v`. Create a new branch and PR.
