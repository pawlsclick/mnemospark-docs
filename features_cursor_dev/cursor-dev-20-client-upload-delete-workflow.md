# Cursor Dev: Client upload/delete workflow (cron job + cron-id)

**ID:** cursor-dev-20  
**Repo:** mnemospark  
**Rough size:** One Cloud Agent run

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark (OpenClaw plugin/client). Do **not** open, clone, or require access to mnemospark-backend or mnemospark-docs; all code and references are in this repo and `.company/`. The workflow spec is in [.company/mnemospark_full_workflow.md](../mnemospark_full_workflow.md) (in this repo: `mnemospark_full_workflow.md` at root). The implementation plan is in the docs repo: [upload_and_delete_workflow](upload_and_delete_workflow.md) plan "Upload and delete workflow docs" (upload/delete client steps and cron-id).

## Scope

Implement the **mnemospark-client** behavior for `/cloud upload` and `/cloud delete` so it matches the new workflow (see plan and workflow doc).

**Upload (after proxy returns success):**

1. Keep: accept response from proxy; write to object.log the upload row: `<YYYY-MM-DD HH:MM:SS>`,`<quote-id>`,`<addr>`,`<addr-hash>`,`<trans-id>`,`<storage-price>`,`<object-id>`,`<object-key>`,`<provider>`,`<bucket-name>`,`<location>` (existing `appendStorageUploadLog`).
2. **New:** Build a cron job (or platform-equivalent scheduled job) to send x402 payment of USDC `<storage-price>` every 30 days for `<object-id>` matching the upload (quote_id / storage_price). Generate and persist a **cron-id** (e.g. UUID or stable id) for this job.
3. **New:** Update the log file (object.log) with the cron-id and the associated `<object-id>` (and `<object-key>`) so the client can find this job later when the user runs `/cloud delete`. Log format is up to you (e.g. a second line per upload: `cron,<cron-id>,<object-id>,<object-key>` or extra fields on the same upload line).
4. **New:** Return **three** separate user messages in order: (5) "Your file `<object-id>` with key `<object-key>` has been stored using `<provider>` in `<bucket-name>` `<location>`"; (6) "A cron job `<cron-job>` has been configured to send payment every 30 days for storage services. If payment is not sent, your `<object-id>` will be deleted after the **32-day deadline** (30-day billing interval + 2-day grace period)."; (7) "Thank you for using mnemospark!"

**Delete (after proxy returns success):**

1. Keep: accept response from proxy.
2. **New:** Look up the cron job associated with the deleted `<object-key>` (using object.log or whatever store holds cron-id ↔ object-key). Delete that cron job (remove from crontab, task scheduler, or in-memory scheduler) so no orphaned payment job remains.
3. **New:** Return **two** user messages: (3) "File `<s3-key>` has been deleted from the cloud and the cron job `<cron-id>` has been deleted from your system." (4) "Thank you for using mnemospark!"

**Cron/scheduler implementation note:** The client runs in Node (OpenClaw plugin). "Cron" can be implemented as: writing a crontab entry to a file under `~/.openclaw/mnemospark/` (e.g. `crontab.txt` or platform-specific), or using a Node scheduler (e.g. `node-cron` or a simple interval that persists across restarts via log). For delete, "delete the cron job" means remove that entry or unregister that job. Support at least macOS and Linux; Windows (Task Scheduler) can be best-effort or documented as future. Ensure cron-id is stored so delete can find and remove the right job.

## References

- [mnemospark_full_workflow.md](../mnemospark_full_workflow.md) — upload command (mnenospark-client steps 1–7), delete command (mnenospark-client steps 1–4) (in mnemospark repo: `.company/mnemospark_full_workflow.md`)
- Plan: Upload and delete workflow docs (upload order, delete order, cron-id) — client steps and [meta_docs/cron-id-usage.md](../meta_docs/cron-id-usage.md) description of cron-id (in mnemospark repo: `.company/meta_docs/cron-id-usage.md`)
- Existing upload flow: [src/cloud-command.ts](https://github.com/pawlsclick/mnemospark/blob/main/src/cloud-command.ts) — `appendStorageUploadLog`, `formatStorageUploadUserMessage`, upload handler; delete handler

## Cloud Agent

- **Install (idempotent):** `npm install`. If adding a scheduler dependency (e.g. `node-cron`), add it to package.json and install.
- **Start (if needed):** None.
- **Secrets:** None beyond existing (wallet, proxy, backend URL).
- **Acceptance criteria (checkboxes):**
  - [ ] After successful `/cloud upload`, client writes the upload row to object.log (existing behavior), then creates a scheduled job for 30-day USDC payment and generates a cron-id.
  - [ ] Client persists cron-id and associated object-id/object-key (in object.log or equivalent) so it can be looked up on delete.
  - [ ] After upload, client returns three messages in order: (1) file stored, (2) cron configured + 32-day deadline, (3) thank you.
  - [ ] After successful `/cloud delete`, client looks up the cron job for the given object-key, removes that cron job, then returns two messages: (1) file and cron deleted, (2) thank you.
  - [ ] If no cron job exists for the object-key on delete (e.g. legacy upload), client still returns the two messages (e.g. "cron job not found" or omit cron-id in message); no crash.
  - [ ] Unit or integration tests: upload success path (log + cron creation + three messages), delete success path (cron removal + two messages); optional: delete when no cron exists.
  - [ ] Lint and build pass.

## Task string (optional)

Work only in this repo (mnemospark). Implement new upload/delete workflow: (1) After upload success: write upload log row, create 30-day payment cron job with a cron-id, persist cron-id and object-id/object-key in log, return three user messages (stored; cron configured + 32-day deadline; thank you). (2) After delete success: look up cron by object-key, delete that cron job, return two messages (file and cron deleted; thank you). Use object.log under ~/.openclaw/mnemospark for persistence. Support macOS and Linux. Acceptance: [ ] upload log + cron + 3 messages; [ ] delete cron removal + 2 messages; [ ] no crash when no cron on delete; [ ] tests; [ ] lint/build.
