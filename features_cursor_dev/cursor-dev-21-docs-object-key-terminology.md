# Cursor Dev: Docs — standardize on object-key (remove s3-key)

**ID:** cursor-dev-21  
**Repo:** mnemospark-docs

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-docs. Documentation and feature specs live here. Do **not** open, clone, or require access to mnemospark, mnemospark-backend, or any other repository. The spec for this feature is at `.company/features_cursor_dev/cursor-dev-21-docs-object-key-terminology.md` when run from a repo that has the docs submodule; when run from mnemospark-docs, the path is `features_cursor_dev/cursor-dev-21-docs-object-key-terminology.md`.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Standardize terminology on **`<object-key>`** only; remove all uses of **`<s3-key>`** in this repo. The key returned from the upload operation and used for ls, download, and delete is a single concept: the object’s storage key (the S3 object key). Use `<object-key>` everywhere for consistency with the backend API (`object_key`).

1. **mnemospark_full_workflow.md**
   - Replace every occurrence of `<s3-key>` with `<object-key>` in:
     - ls command: command signature, argument description, step “Takes the arguments”, backend “Expects”, client “Print message to user”.
     - download command: same pattern.
     - delete command: same pattern (including the delete success message “File `<s3-key>` has been deleted...”).
   - Optionally add one sentence in the “mnemospark file locations” or “full workflow” section: `<object-key>` is the storage key for the object (the key under which it is stored in S3 and returned by the upload API).

2. **features_cursor_dev/**
   - **cursor-dev-19-workflow-upload-delete-cron-id.md:** Replace the delete user message “File `<s3-key>` has been deleted...” with “File `<object-key>` has been deleted...”.
   - **cursor-dev-20-client-upload-delete-workflow.md:** Replace “File `<s3-key>` has been deleted...” with “File `<object-key>` has been deleted...” in the “Return **two** user messages” bullet.
   - **upload_and_delete_workflow.md:** No `<s3-key>` found; leave as-is or ensure any key placeholder is `<object-key>`.

Do not change API field names or code; this is documentation and placeholder terminology only.

## References

- [mnemospark_full_workflow.md](../product_docs/mnemospark_full_workflow.md) — full workflow (ls, download, delete sections)
- [cursor-dev-19-workflow-upload-delete-cron-id.md](cursor-dev-19-workflow-upload-delete-cron-id.md), [cursor-dev-20-client-upload-delete-workflow.md](cursor-dev-20-client-upload-delete-workflow.md), [upload_and_delete_workflow.md](upload_and_delete_workflow.md)

## Cloud Agent

- **Install (idempotent):** None (markdown only).
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] mnemospark_full_workflow.md: every `<s3-key>` replaced with `<object-key>` in ls, download, and delete command sections (command line, argument descriptions, steps, user messages).
  - [ ] cursor-dev-19-workflow-upload-delete-cron-id.md: delete user message uses `<object-key>`.
  - [ ] cursor-dev-20-client-upload-delete-workflow.md: delete user message uses `<object-key>`.
  - [ ] No new uses of `<s3-key>` remain in the modified files.
  - [ ] Optional: one-sentence clarification that `<object-key>` is the object’s storage key (S3 key) added where appropriate.

## Task string (optional)

Work only in this repo (mnemospark-docs). Standardize on `<object-key>`: replace all `<s3-key>` with `<object-key>` in mnemospark_full_workflow.md (ls, download, delete) and in features_cursor_dev cursor-dev-19, cursor-dev-20. Optional: add one sentence that object-key is the storage key for the object. Acceptance: [ ] workflow doc updated; [ ] feature specs updated; [ ] no s3-key remaining.
