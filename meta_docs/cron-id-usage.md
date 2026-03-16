# `<cron-id>` (cron job id) in mnemospark

**Date:** 2026-03-16  
**Revision:** rev 1  
**Milestone:** e2e-staging-2026-03-16 (mnemospark)  
**Repos / components:** mnemospark (client)

## What `<cron-id>` is

`<cron-id>` is the **client-side identifier** for the scheduled job (cron) that sends the 30-day USDC payment for a stored object.

## When it is created

After a successful `/cloud upload`, when the client builds the cron job (workflow step 3), the client generates and stores a `<cron-id>` (or `<cron-job>` id).

## Where it is stored

In `~/.openclaw/mnemospark/object.log` — the client updates the log (workflow step 4) to add fields for the cron job id and the associated `<object-id>` (and optionally `<object-key>`) so the same job can be found later.

## How it is used

On `/cloud delete`, after the proxy returns success and the object is deleted from S3, the client looks up the cron job for that `<object-key>` (via log or local mapping), deletes that cron job using `<cron-id>`, then prints the two user messages. This avoids leaving orphaned cron jobs that would keep trying to pay for a deleted object.

---

## Spec references

- This doc: `meta_docs/cron-id-usage.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cron-id-usage.md`
- Delete flow: `meta_docs/cloud-delete-process-flow.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/cloud-delete-process-flow.md`
- Milestone overview: `meta_docs/e2e-staging-milestone-2026-03-16.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/e2e-staging-milestone-2026-03-16.md`
