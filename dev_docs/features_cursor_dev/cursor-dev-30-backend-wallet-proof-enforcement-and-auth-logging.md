# Cursor Dev: Wallet proof enforcement and authorizer logging

**ID:** cursor-dev-30  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. It contains the SAM template (`template.yaml`), the wallet authorizer under `services/wallet-authorizer`, and all Lambda handlers for the storage and pricing APIs. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Tighten wallet proof enforcement so that **all public API endpoints require a valid wallet proof**, and introduce a dedicated DynamoDB table for structured authorizer logging.

In more detail:

- In `services/wallet-authorizer/app.py`:
  - Ensure the route classification logic covers all internet-facing routes from `template.yaml`:
    - `POST /price-storage`
    - `POST /storage/upload`
    - `POST /storage/upload/confirm`
    - `GET,POST /storage/ls`
    - `GET,POST /storage/download`
    - `POST,DELETE /storage/delete`
  - Remove or refactor any “wallet-proof optional” behavior so that:
    - `/price-storage` **now requires** a valid wallet proof, just like the storage routes.
    - All supported routes deny requests when `X-Wallet-Signature` is missing, malformed, or invalid.
  - Keep and enhance the existing debug logs (`authorizer_debug_*`) to emit **structured, JSON-friendly** messages that include:
    - Method, normalized path, route classification.
    - Presence of the wallet header and basic validation outcomes.
    - Wallet address recovered from the signature (when available).
    - High-level error reasons (e.g. `wallet_mismatch`, `expired_signature`, `unsupported_route`).
- Introduce a new **DynamoDB table** (e.g. `${StackName}-wallet-auth-events`) in `template.yaml`:
  - Define a simple primary key (e.g. `event_id` as `HASH`) and any minimal secondary attributes you need.
  - Configure PAY_PER_REQUEST billing and appropriate TTL for the events, if desired.
- In the wallet authorizer Lambda:
  - Add a lightweight logging function that **writes a row into the `wallet-auth-events` table** for each evaluated request (or at least for failures), including:
    - Event timestamp.
    - Method and path.
    - Wallet address recovered (if any).
    - Result: `allow` or `deny`.
    - Reason / error code when denied.
    - The API Gateway `methodArn`/`routeArn` if available.
  - Keep this logging best-effort: do not allow DynamoDB failures to break the auth decision path (fallback to logging only to CloudWatch if necessary).
- Update IAM in `template.yaml` so the authorizer function has least-privilege access to the new `wallet-auth-events` table.
- Do **not** change any integration Lambda handlers in this task (e.g. price-storage, storage-upload); those will be updated in later tasks.

Depends on cursor-dev-29 (Backend OAS 3.2 skeleton and endpoint inventory) for the finalized list of routes and canonical path/method mapping.

## References

- `services/wallet-authorizer/app.py` (existing wallet proof authorizer).
- `template.yaml` (API routes, Auth configuration, Lambda definitions).
- `mnemospark-docs/meta_docs/wallet-proof.md` (wallet proof semantics and header format).
- `dev_docs/features_cursor_dev/cursor-dev-29-backend-oas-skeleton-and-inventory.md` (route inventory and spec skeleton).

## Agent

- **Install (idempotent):** `pip install -r requirements.txt || true`
- **Start (if needed):** None.
- **Secrets:** None (use local SAM/lint/test only; do not depend on live AWS credentials for this task).
- **Acceptance criteria (checkboxes):**
  - [ ] The authorizer enforces wallet proof on **all** public API routes, including `/price-storage`.
  - [ ] Requests without a valid `X-Wallet-Signature` header are denied with clear, structured debug logs.
  - [ ] A new `wallet-auth-events` DynamoDB table is defined in `template.yaml` with appropriate billing and TTL configuration.
  - [ ] The authorizer writes a best-effort event record for each evaluated request (or at minimum all denied requests) into `wallet-auth-events`.
  - [ ] The authorizer IAM role has least-privilege access to the `wallet-auth-events` table, and no excessive permissions are introduced.

## Task string (optional)

Work only in the `mnemospark-backend` repo. Update `services/wallet-authorizer/app.py` and `template.yaml` so that all public API routes (`/price-storage` and all `/storage/*` paths) strictly require a valid wallet proof, and add a new `wallet-auth-events` DynamoDB table that records structured authorizer decisions. Keep logging structured and JSON-friendly, and ensure DynamoDB logging is best-effort and does not interfere with the auth decision path. Acceptance: [ ] all routes require wallet proof, [ ] new table and IAM are defined, [ ] authorizer writes auth events to DynamoDB and CloudWatch with clear reasons for allow/deny.

