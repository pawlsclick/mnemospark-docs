Name: Upload and delete workflow docs
Overview: Update mnemospark_full_workflow.md with the new upload client order (including cron-id in log), the new delete client order (cron removal + messages), and add a meta_docs file for cron-id. Optionally adjust the file-locations note for object.log.
1. mnemospark_full_workflow.md
1a. Upload command — Replace the mnenospark-client 4-step list with a 7-step list: accept response → write log → build 30-day cron → update log with <cron-job> id and <object-id> → three user messages (stored; cron + 32-day deadline; thank you). (Use "message" not "mesage".)
1b. Delete command — Replace the mnenospark-client 2-step list with a 4-step list: accept response → delete cron for <cron-id> / <object-key> → “File … and cron job … deleted” → “Thank you for using mnemospark!” Use mnenospark-proxy (fix typo "mnemosparek").
1c. File locations (optional) — Extend the “Logs: ~/.openclaw/mnemospark/object.log” bullet to say the client appends upload and payment-cron rows and that upload rows may include <cron-id> and <object-id> for cron tracking.
2. New meta_docs: cron-id usage
Add meta_docs/cron-id-usage.md with:
What it is: Client-side id for the 30-day USDC payment cron.
When created: After successful /cloud upload when the client builds the cron (step 3).
Where stored: In ~/.openclaw/mnemospark/object.log (client adds cron job id and <object-id> / optionally <object-key> in step 4).
How used: On /cloud delete, client finds the cron for that <object-key>, deletes it with <cron-id>, then shows the two user messages; avoids orphaned cron jobs.
Style should match trans-id-payment-settement.md and quote-id-dynamodb.md.
3. Other docs (no change or optional)
[install_guidelines.md](../product_docs/install_guidelines.md) — No update.
mnemospark_backend_api_spec.md — No update.
cursor-dev-13, cursor-dev-14 — Can reference the new order/cron-id later; not required for this pass.
4. Implementation order
Apply upload client steps in mnemospark_full_workflow.md.
Apply delete client steps in the same file.