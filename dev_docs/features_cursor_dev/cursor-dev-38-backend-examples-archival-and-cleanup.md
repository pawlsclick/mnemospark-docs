# Cursor Dev: Backend examples archival and cleanup

**ID:** cursor-dev-38  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. It contains the production backend stack and early example SAM templates under `examples/`. Do **not** clone, or require access to any other repository; all code and references are in this file References: see below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Gracefully remove or archive non-required functionality from the mnemospark-backend repo based on the changes made in previous tasks, without impacting the production backend.

In more detail:

- **Archive early examples**:
  - Move the POC SAM templates and code under `examples/` into a dedicated `archive/` directory (for example, `archive/examples/`), preserving their structure but clearly marking them as non-production.
  - Update any README or docs in mnemospark-backend to:
    - State that `archive/` contains legacy proofs-of-concept.
    - Point new contributors to the current production stack in `template.yaml` and `services/`.
- **Clean up unused or redundant resources**:
  - Identify any resources, functions, or templates that are no longer part of the supported product surface after:
    - Strict wallet proof enforcement.
    - Introduction of `/payment/settle`.
    - Upload refactor and updated logging.
  - Remove or relocate:
    - Dead test code that only targets archived examples.
    - Any documentation that describes flows superseded by the new architecture.
- Ensure:
  - The main `template.yaml` and `services/` code reflect only the **supported live endpoints** and housekeeping.
  - The OpenAPI spec and endpoint docs (cursor-dev-36) reference only the active API surface.

Depends on:
- cursor-dev-29–37 (so cleanup decisions are made against the final, revised backend shape).

## References

- `examples/*` in mnemospark-backend.
- `template.yaml`.
- `mnemospark-backend/docs/*` (to ensure docs only reference supported resources).
- `dev_docs/features_cursor_dev/cursor-dev-29-backend-oas-skeleton-and-inventory.md` through `cursor-dev-37-backend-e2e-tests-aligned-to-new-flows.md`.

## Agent

- **Install (idempotent):** `pip install -r requirements.txt || true`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] All early example SAM templates and code under `examples/` are moved into an `archive/` directory or otherwise clearly marked as non-production.
  - [ ] No archived code is referenced by the main `template.yaml` or production Lambdas.
  - [ ] Tests and docs no longer reference archived examples as part of the supported product surface.
  - [ ] The repository structure clearly distinguishes active backend code from archived/legacy artifacts.

## Task string (optional)

Work only in the `mnemospark-backend` repo. Move early example SAM templates and code into an `archive/` directory and remove or update any remaining references so that only the current production backend stack and housekeeping remain in the active surface. Acceptance: [ ] examples archived, [ ] no active references to archived code, [ ] docs and tests reflect only supported endpoints and flows.

