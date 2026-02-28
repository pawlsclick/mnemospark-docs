# Cursor Dev: Workflow doc upload/delete order and cron-id meta doc

**ID:** cursor-dev-19  
**Repo:** mnemospark-docs  
**Rough size:** One Cloud Agent run

**Plan coverage:** This file implements the full plan "Upload and delete workflow docs" scope for the **mnemospark-docs** repo: (1) mnemospark_full_workflow.md upload client 7-step list, (2) delete client 4-step list, (3) optional file-locations Logs bullet, (4) new meta_docs/cron-id-usage.md. All other docs (install_guidelines, mnemospark_backend_api_spec, cursor-dev-13/14) are out of scope per the plan (no change or optional later). Client code that implements this workflow is in **cursor-dev-20** (mnemospark repo).

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-docs. Documentation and workflow specs live here. Do **not** open, clone, or require access to mnemospark or mnemospark-backend; all files to edit are in this repo. The spec for this feature is at [cursor-dev-19-workflow-upload-delete-cron-id.md](cursor-dev-19-workflow-upload-delete-cron-id.md) (this file).

## Scope

1. **mnemospark_full_workflow.md — Upload command (mnenospark-client):** Replace the current 4-step list under **mnenospark-client** (after "Returns response to **mnenospark-client**" and before "### ls command") with the following 7-step list:
   - 1. Accepts response from **mnenospark-proxy**
   - 2. Writes to log file: `<YYYY-MM-DD HH:MM:SS>`,`<quote-id>`,`<addr>`,`<addr-hash>`,`<trans-id>`,`<storage-price>`,`<object-id>`,`<object-key>`,`<provider>`,`<bucket-name>`,`<location>`
   - 3. Builds a cron job to send x402 payment of USDC `<storage-price>` **every 30 days** for `<object-id>` matching the `<quote-id>` and `<storage-price>`.
   - 4. Update the log file: add fields for the `<cron-job>` id and the associated `<object-id>`
   - 5. Print message to user: Your file `<object-id>` with key `<object-key>` has been stored using `<provider>` in `<bucket-name>` `<location>`
   - 6. Print message to user: A cron job `<cron-job>` has been configured to send payment every 30 days for storage services. If payment is not sent, your `<object-id>` will be deleted after the **32-day deadline** (30-day billing interval + 2-day grace period).
   - 7. Print message to user: Thank you for using mnemospark!

2. **mnemospark_full_workflow.md — Delete command (mnenospark-client):** Replace the current 2-step list under **mnenospark-client** for the delete command (after "Returns response to **mnenospark-client**" and before "### wallet command") with the following 4-step list:
   - 1. Accepts response from **mnenospark-proxy**
   - 2. Deletes the cron job associated with `<cron-id>` for `<object-key>`
   - 3. Print message to user: File `<s3-key>` has been deleted from the cloud and the cron job `<cron-id>` has been deleted from your system.
   - 4. Print message to user: Thank you for using mnemospark!

3. **mnemospark_full_workflow.md — File locations (optional):** In the "mnenospark file locations" section, extend the "Logs: `~/.openclaw/mnemospark/object.log`" bullet with one sentence noting that the client appends upload and payment-cron rows to this log, and that upload rows may include `<cron-id>` and `<object-id>` for cron tracking.

4. **meta_docs/cron-id-usage.md (new file):** Create a short meta doc describing `<cron-id>` (or `<cron-job>` id): what it is (client-side identifier for the 30-day USDC payment cron job), when it is created (after successful upload when the client builds the cron), where it is stored (in object.log; client updates the log with cron job id and associated object-id/object-key), and how it is used (on `/cloud delete`, client looks up and deletes the cron job for that object-key so no orphaned cron remains). Match the style of existing meta_docs (e.g. [meta_docs/trans-id-payment-settement.md](../meta_docs/trans-id-payment-settement.md), [meta_docs/quote-id-dynamodb.md](../meta_docs/quote-id-dynamodb.md)).

## References

- [mnemospark_full_workflow.md](../mnemospark_full_workflow.md) — upload command (§ upload command), delete command (§ delete command), mnenospark file locations
- Plan "Upload and delete workflow docs" — full change list (local: `.cursor/plans/upload_and_delete_workflow_docs_bfdc69d4.plan.md`; not in this repo)
- [meta_docs/trans-id-payment-settement.md](../meta_docs/trans-id-payment-settement.md), [meta_docs/quote-id-dynamodb.md](../meta_docs/quote-id-dynamodb.md) — style reference for cron-id meta doc

## Cloud Agent

- **Install (idempotent):** None (markdown only).
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] Upload command **mnenospark-client** list in mnemospark_full_workflow.md is replaced with the 7-step list (accept response, write log, build cron, update log with cron-job id, then three print messages).
  - [ ] Delete command **mnenospark-client** list in mnemospark_full_workflow.md is replaced with the 4-step list (accept response, delete cron job for cron-id/object-key, two print messages including thank-you).
  - [ ] Optional: "mnenospark file locations" Logs bullet mentions object.log and cron-id/object-id for upload rows.
  - [ ] New file meta_docs/cron-id-usage.md exists; describes what cron-id is, when created, where stored, how used (delete); style consistent with other meta_docs.

## Task string (optional)

Work only in this repo (mnemospark-docs). (1) In mnemospark_full_workflow.md replace the upload command mnenospark-client steps with the 7-step list (write log, build cron, update log with cron-job id, then three user messages). (2) Replace the delete command mnenospark-client steps with the 4-step list (accept response, delete cron for cron-id/object-key, two print messages). (3) Optionally extend the Logs bullet in file locations for object.log and cron-id. (4) Create meta_docs/cron-id-usage.md describing cron-id (what, when created, where stored, how used on delete); match style of trans-id and quote-id meta_docs. Acceptance: [ ] upload 7 steps; [ ] delete 4 steps; [ ] optional file locations; [ ] cron-id-usage.md.
