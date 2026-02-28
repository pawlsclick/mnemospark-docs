# Cursor Dev: Backend — verify object_key only (no s3-key)

**ID:** cursor-dev-23  
**Repo:** mnemospark-backend

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. Backend Lambdas and templates live here. Do **not** open, clone, or require access to mnemospark or any other repository; all code and references are in this repo and `.company/`. The spec for this feature is at `.company/features_cursor_dev/cursor-dev-23-backend-verify-object-key-only.md`.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Verify that the mnemospark-backend uses only **object_key** (snake_case) for the storage key concept everywhere: API request/response, Lambda handlers, DynamoDB transaction log, and templates. There should be no use of `s3_key`, `s3-key`, or `s3Key` in backend code or config. This is a **verification task**; no code or API changes are expected.

1. **Search and confirm**
   - In the backend repo (excluding `.company/` which is the docs submodule), search for: `s3_key`, `s3-key`, `s3Key`. Expect zero matches in application code, templates, and tests.
   - Confirm that upload, ls, download, delete, and housekeeping Lambdas use the field name `object_key` in request parsing, response bodies, transaction log, and S3 Key parameters.

2. **If any s3_key / s3-key / s3Key is found**
   - Replace with `object_key` (or the correct existing name) so the backend uses a single term. Update tests and templates as needed.

3. **Document the outcome**
   - In the PR or in a short comment: state that the backend uses only `object_key` and no changes were required (or list the minimal changes made). No new docs repo edits in this task (docs live in mnemospark-docs).

No changes to API contracts or behavior; terminology is already aligned on object_key.

## Handoff

After completing the verification (and any minimal renames): **open a new branch** (e.g. from `main`), **commit** all changes, **push** the branch, and **create a PR** for review. Do not commit directly to `main`/`master`.

## References

- [mnemospark_full_workflow.md](../mnemospark_full_workflow.md) — workflow (object-key terminology)
- Backend: `services/storage-upload/app.py`, `services/storage-ls/`, `services/storage-download/`, `services/storage-delete/`, `services/storage-housekeeping/`, `template.yaml`

## Cloud Agent

- **Install (idempotent):** `pip install -r requirements.txt` (or project equivalent) if running tests.
- **Start (if needed):** None.
- **Secrets:** None for verification.
- **Acceptance criteria (checkboxes):**
  - [ ] Search of backend code (excluding .company/) for s3_key, s3-key, s3Key returns no matches (or only false positives, e.g. in comments that are then updated).
  - [ ] Upload, ls, download, delete, and housekeeping code paths use object_key in API and S3 Key usage.
  - [ ] If any s3_key/s3-key/s3Key was found, it has been replaced with object_key and tests/templates updated.
  - [ ] Outcome documented (no changes required, or brief list of changes) in PR or spec.
  - [ ] Existing tests still pass.
  - [ ] Handoff: new branch opened, changes committed and pushed, PR created.

## Task string (optional)

Work only in this repo (mnemospark-backend). Verify backend uses only object_key; search for s3_key, s3-key, s3Key in code and templates (exclude .company). Confirm no changes needed or make minimal renames to object_key. Document outcome. Acceptance: [ ] no s3_key/s3-key/s3Key in backend; [ ] object_key used throughout; [ ] tests pass; [ ] outcome documented.
