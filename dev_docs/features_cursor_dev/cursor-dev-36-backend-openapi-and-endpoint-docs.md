# Cursor Dev: Backend OpenAPI 3.2 and endpoint docs

**ID:** cursor-dev-36  
**Repo:** mnemospark-docs
**Repo:** mnemospark-backend


**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources, but this task is documentation-only and should not modify live infrastructure.

## Scope

Refine and finalize the **OpenAPI 3.2.0 specification** and add per-endpoint documentation for all mnemospark-backend API endpoints, following the Cursor Cloud documentation pattern.

In more detail:

- OpenAPI spec (`mnemospark-backend/docs/openapi.yaml` in the backend repo):
  - Update the existing skeleton from cursor-dev-29 to fully describe:
    - `POST /price-storage`
    - `POST /payment/settle`
    - `POST /storage/upload`
    - `POST /storage/upload/confirm`
    - `GET,POST /storage/ls`
    - `GET,POST /storage/download`
    - `POST,DELETE /storage/delete`
  - For each operation:
    - Define accurate request bodies and parameters based on the final Lambda handlers and SAM models (including fields like `quote_id`, `wallet_address`, `object_id`, `object_key`, `mode`, payment payload, etc.).
    - Define response schemas for:
      - 2xx success responses.
      - 4xx error variants (400, 402, 403, 404, 409, 405 where applicable).
      - 5xx error (generic internal error).
    - Reference shared components for common error structures where practical.
  - Model wallet proof authentication explicitly:
    - A `securitySchemes.walletProof` section that documents `X-Wallet-Signature` behavior at a high level.
    - Apply this security scheme to all wallet-scoped endpoints via `security` entries.
  - Validate the spec against OpenAPI 3.2.0 using an appropriate validator (CLI or library) and fix any issues.
- Backend endpoint docs under `mnemospark-backend/docs`:
  - For each endpoint, create or update a Markdown file (one file per endpoint) that follows the Cursor Cloud-style pattern, including:
    - A short summary and high-level description.
    - Auth requirements (wallet proof header).
    - Request shape (fields, types, constraints).
    - Response examples for success and common error cases.
    - Notes on idempotency and payment requirements where relevant (e.g. upload requiring prior payment).
  - Expected files (names can be adjusted slightly if needed, but document the mapping):
    - `price-storage.md`
    - `payment-settle.md`
    - `storage-upload.md`
    - `storage-upload-confirm.md`
    - `storage-ls.md`
    - `storage-download.md`
    - `storage-delete.md`
- In `mnemospark-docs/product_docs` or an appropriate location, add a short overview section linking:
  - The product-level description of the backend.
  - The OpenAPI spec (`mnemospark-backend/docs/openapi.yaml`).
  - The per-endpoint docs.

Depends on:
- cursor-dev-29 (Backend OAS 3.2 skeleton and endpoint inventory).
- cursor-dev-30–35 (so the spec reflects the final behavior after wallet proof enforcement, logging, payment separation, upload refactor, and IAM changes).

## References

- `mnemospark-backend/docs/openapi.yaml` (skeleton from cursor-dev-29; open and edit it via this spec).
- `mnemospark-backend/services/*/app.py` for each endpoint to confirm request/response shapes.
- `mnemospark-docs/meta_docs/wallet-proof.md` (wallet proof details).
- `mnemospark-docs/meta_docs/cloud-upload-process-flow.md`.
- `mnemospark-docs/meta_docs/cloud-price-storage-process-flow.md`.
- `dev_docs/features_cursor_dev/cursor-dev-29-backend-oas-skeleton-and-inventory.md`.
- `dev_docs/features_cursor_dev/cursor-dev-30-backend-wallet-proof-enforcement-and-auth-logging.md`.
- `dev_docs/features_cursor_dev/cursor-dev-31-backend-api-call-logging-dynamodb.md`.
- `dev_docs/features_cursor_dev/cursor-dev-32-backend-payment-settle-endpoint.md`.
- `dev_docs/features_cursor_dev/cursor-dev-33-backend-storage-upload-require-payment-record.md`.
- `dev_docs/features_cursor_dev/cursor-dev-34-backend-logging-and-housekeeping-alignment.md`.
- `dev_docs/features_cursor_dev/cursor-dev-35-backend-iam-tightening-and-new-resources.md`.
- `https://cursor.com/docs/cloud-agent/api/endpoints` (Cursor Cloud-style pattern pattern for API documentation)

## Agent

- **Install (idempotent):** `pip install -r requirements.txt || true`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] `mnemospark-backend/docs/openapi.yaml` is a valid OpenAPI 3.2.0 spec covering all backend endpoints with accurate request/response and error modeling.
  - [ ] Wallet proof authentication is documented as a security scheme and applied to all wallet-scoped operations.
  - [ ] Per-endpoint docs exist in `mnemospark-backend/docs` for each public endpoint, following the Cursor Cloud-style pattern.
  - [ ] Product-level docs in `mnemospark-docs` link to the OpenAPI spec and endpoint docs for discoverability.

## Task string (optional)

Finalize the mnemospark-backend OpenAPI 3.2.0 spec and per-endpoint documentation so they accurately reflect the behavior of `/price-storage`, `/payment/settle`, and all `/storage/*` endpoints, including wallet proof auth, payment requirements, idempotency, and error contracts. Validate the spec, ensure each endpoint has a dedicated Markdown doc in the backend repo, and add product-level links in `mnemospark-docs`. Acceptance: [ ] spec validates, [ ] all endpoints documented, [ ] docs clearly describe wallet proof and payment flows.


