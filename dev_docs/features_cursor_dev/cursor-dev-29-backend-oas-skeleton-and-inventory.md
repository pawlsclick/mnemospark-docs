# Cursor Dev: Backend OAS 3.2 skeleton and endpoint inventory

**ID:** cursor-dev-29  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. It contains the serverless backend for mnemospark, including the main SAM template (`template.yaml`), Lambda handlers under `services/`, and backend docs under `docs/`. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Implement a first-pass, descriptive **OpenAPI 3.2.0 skeleton** for the existing mnemospark-backend API and capture a precise inventory of current externally exposed endpoints.

In more detail:

- Parse `template.yaml` to identify all **public API Gateway routes** and their Lambda integrations:
  - `POST /price-storage`
  - `POST /storage/upload`
  - `POST /storage/upload/confirm`
  - `GET,POST /storage/ls`
  - `GET,POST /storage/download`
  - `POST,DELETE /storage/delete`
  - Confirm there are no other internet-facing routes (only scheduled / internal ones like `storage-housekeeping`).
- Create a new **OpenAPI 3.2.0 spec file** at `docs/openapi.yaml` that:
  - Defines a single API for the current unversioned paths (no `/api/v1` prefix yet).
  - Includes:
    - `openapi: "3.2.0"`.
    - A top-level `info` block with a suitable `title`, `version`, and brief description.
    - A single `servers` entry pointing at a placeholder or documented base URL (do **not** hardcode secrets).
  - For each operation:
    - Add `paths` entries with the **current paths and methods**.
    - Define request bodies and parameters using existing API Gateway models from `template.yaml` (e.g. `PriceStorageRequest`, `StorageUploadRequest`, `UploadConfirmRequest`, `StorageObjectRequest`) as a guide.
    - Define basic 2xx and representative error responses (200/400/403/404/500) with generic schemas for now.
  - Define a **wallet-proof security scheme placeholder**:
    - A `securitySchemes.walletProof` entry (e.g. `type: http`, `scheme: bearer`, or `type: apiKey` in header) that will be refined in a later task to model the `X-Wallet-Signature` behavior.
    - Apply this security scheme to all operations at the path or operation level, but keep descriptions high-level (detailed behavior will come later).
- Add a short `docs/README.md` or update an existing docs file to:
  - Explain that `docs/openapi.yaml` is the **canonical API contract** for mnemospark-backend.
  - Note that current paths are considered “v1” semantics even though they are not yet prefixed with `/api/v1`.

This task is **descriptive only**: no behavioral changes to Lambda code, IAM, or API Gateway configuration. It sets the foundation for subsequent tasks that will tighten wallet proof enforcement, add logging, and introduce new endpoints.

## References

- `template.yaml` (for current routes, models, and integration wiring).
- `services/price-storage/app.py` (request/response shape for `/price-storage`).
- `services/storage-upload/app.py` (inline vs presigned upload flows).
- `services/storage-ls/app.py`, `services/storage-download/app.py`, `services/storage-delete/app.py` (storage object operations).
- `mnemospark-docs/meta_docs/wallet-proof.md` (high-level wallet proof concept; do not fully model it yet).

## Agent

- **Install (idempotent):** `pip install -r requirements.txt || true`
- **Start (if needed):** None.
- **Secrets:** None (do not call live AWS endpoints in this task; static analysis only).
- **Acceptance criteria (checkboxes):**
  - [ ] `docs/openapi.yaml` exists, is valid OpenAPI 3.2.0, and describes all current public endpoints and methods.
  - [ ] Each operation has a defined request body/parameters that match the existing Lambda handlers’ expectations.
  - [ ] Each operation has at least basic 2xx and error response schemas.
  - [ ] A wallet-proof security scheme placeholder is defined and referenced by all operations.
  - [ ] A short docs entry in `docs/` explains that `docs/openapi.yaml` is the canonical API contract and that current paths correspond to v1 behavior.

## Task string (optional)

Work only in the `mnemospark-backend` repo. Read `template.yaml` and the Lambda handlers under `services/` to produce a new `docs/openapi.yaml` that is a valid OpenAPI 3.2.0 spec describing all current public endpoints and methods. Define request bodies and parameters based on existing models, add basic success and error responses, and introduce a wallet-proof security scheme placeholder applied to all operations. Do not change any Lambda behavior or infrastructure beyond adding docs files. Acceptance: [ ] all routes are covered, [ ] OpenAPI validates, [ ] docs note `docs/openapi.yaml` as the canonical API spec.

