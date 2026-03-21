# Cursor Cloud Agent feature specs (mnemospark)

Small, single-run feature specs for [Cursor Cloud Agents](https://cursor.com/docs/cloud-agent). Each file describes one task completable in one Cloud Agent run.

**Product context:** [mnemospark_PRD.md](../product_docs/mnemospark_PRD.md), [mnemospark_full_workflow.md](../product_docs/mnemospark_full_workflow.md), [mnemospark_backend_api_spec.md](../product_docs/mnemospark_backend_api_spec.md). Larger feature specs live in [features/](../features/).

---

## How to use

1. Pick a feature file below (or from the list in this directory).
2. Start a **Cloud Agent** (Cloud dropdown in the agent input, or [cursor.com/agents](https://cursor.com/agents)).
3. Paste the **task string** from the feature file (or point the agent at the file) so it knows scope and acceptance criteria. When the agent runs from any repo, reference the feature spec path in the **mnemospark-docs** repo (e.g. `dev_docs/features/cursor-dev-auth-01-lambda-authorizer.md`).
4. The agent works on a **separate branch** and pushes for handoff; verify via "Checkout Branch" or "Open VM" as needed.

---

## Repo mapping (where to run the Cloud Agent)

- **Backend features (01–10, 15–18, 23, 28, auth-01–auth-04):** Start the Cloud Agent from the **mnemospark-backend** repo, and also open the **mnemospark-docs** repo for the corresponding feature spec under `dev_docs/features/`.
- **Client features (11–14, 20, 22, 26, auth-05–auth-07):** Start the Cloud Agent from the **mnemospark** repo.
- **Docs-only features (19, 21, 27):** Start the Cloud Agent from the **mnemospark-docs** repo. No submodule; edit files directly in this repo.

The agent must work **only in the repo it was started in**. Do **not** open, clone, or require access to BlockRun/ClawRouter, OpenRouter, or any other repository.

| Features                      | Repo to run agent from | Notes                                                                                                                                                                                                                                                                                                                                                      |
| ----------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 01–10, 15–18, 23, 28, 48, auth-01–auth-04 | **mnemospark-backend** | Submodule init (see above). Backend infra (08, 15–17) per [infrastructure_design/internet_facing_API.md](../infrastructure_design/internet_facing_API.md). Secrets (18): [infrastructure_design/secrets_management.md](../infrastructure_design/secrets_management.md). Auth: [auth_no_api_key_wallet_proof_spec.md](../product_docs/auth_no_api_key_wallet_proof_spec.md). 23 = verify object_key only. **48** = `/storage/ls` S3 list mode. |
| 11–14, 20, 22, 26, 49, auth-05–auth-07   | **mnemospark**         | Plugin/client. 20 = upload/delete workflow (cron job + cron-id). 22 = client/proxy object-key terminology. **49** = wallet-only `ls` + friendly names (after **48** deployed).                                                                                                                                                                                                                                                                                                                   |
| 19, 21, 27                            | **mnemospark-docs**    | 19 = workflow doc and meta_docs (upload/delete order, cron-id). 21 = docs object-key terminology (replace s3-key). No code; markdown only.                                                                                                                                                                                                                                                                                   |

**mnemospark proxy port:** For client features (11–14), the mnemospark proxy listens on **port 7120** by default. Agents and config should use `http://127.0.0.1:7120` when talking to the proxy (configurable via `MNEMOSPARK_PROXY_PORT`).

**AWS documentation (CloudFormation/SAM):** Cloud Agents should use the AWS MCP server it is enabled and available https://knowledge-mcp.global.api.aws when implementing features follow AWS Best Practices for API Gateway, Lambda, DynamoDB, WAF, CloudWatch, CloudFront, SAM.

Fall back to **[AWS_DOCS_REFERENCES.md](AWS_DOCS_REFERENCES.md)** for official AWS doc URLs (API Gateway, Lambda, DynamoDB, WAF, CloudWatch, CloudFront, SAM). Fetch or open those URLs as needed for resource syntax and properties.

---

## Conventions

Each feature file includes:

- **ID, Repo, Rough size** — one Cloud Agent run.
- **Scope** — what to build in this run only.
- **References** — links to API spec, workflow, design doc, or examples.
- **Cloud Agent** — install (idempotent), start (if needed), secrets, **acceptance criteria (checkboxes)**.
- **Task string (optional)** — copy-paste prompt for the agent.

---

## Path to feature files when running from a code repo

Feature specs live only in the **mnemospark-docs** repo under `dev_docs/features/`. When running a Cloud Agent from `mnemospark` or `mnemospark-backend`, also open `mnemospark-docs` and reference the feature path there (e.g. `dev_docs/features/cursor-dev-auth-01-lambda-authorizer.md`).

---

## Documentation

**Documentation:** This repo (`mnemospark-docs`) is the single source of truth for mnemospark and mnemospark-backend documentation. When running a Cloud Agent from **mnemospark** or **mnemospark-backend**, do **not** edit docs in those repos; make all documentation changes (including API spec, feature specs, and READMEs) only in the **mnemospark-docs** repo.

---

## Ordering / dependencies

- **01, 02, 09** before **03** (price-storage needs estimate Lambdas and DynamoDB).
- **09** before **04** (upload needs transaction log table).
- **08** (API Gateway) can be done after the first Lambda exists; implement via CloudFormation or SAM.
- **15** (WAF), **16** (observability), **17** (CloudFront, optional) after **08**.
- **10** (housekeeping) after **04** (upload).
- **18** (secrets: relayer key in Secrets Manager) after **04** (upload Lambda exists); implements [infrastructure_design/secrets_management.md](../infrastructure_design/secrets_management.md).
- **11–14** (client) after backend routes exist.
- **Auth (wallet proof):** auth-01 before auth-02 (authorizer must exist before attaching). auth-02 and auth-04 coordinate so Gateway and Lambdas switch coherently. auth-05 before auth-06 (signing module used by proxy). auth-06 depends on backend accepting wallet proof (auth-01, auth-02, auth-04). See [auth_no_api_key_wallet_proof_spec.md](../product_docs/auth_no_api_key_wallet_proof_spec.md).
- **21, 22, 23 (object-key terminology):** Can run in any order. 21 = docs (mnemospark-docs). 22 = client/proxy (mnemospark). 23 = backend verification (mnemospark-backend; no changes expected).
- **26, 27, 28 (mnemospark command structure):** 26 = mnemospark (client: /mnemospark_wallet, /mnemospark_cloud and subcommands, MNEMOSPARK_WALLET_KEY, resolution order). 27 = mnemospark-docs (docs and test scripts — workflow doc client commands, wallet/cloud/env naming). 28 = mnemospark-backend (verify no breakage, update doc refs to /mnemospark_wallet and /mnemospark_cloud). 27 and 28 depend on 26.
- **48, 49 (storage ls — S3 list + friendly names):** 48 = mnemospark-backend (`/storage/ls` list mode via `ListObjectsV2`, optional `object_key`). 49 = mnemospark (wallet-only `ls`, parse list response, SQLite friendly-name enrichment). **49 depends on 48** being merged and **deployed** before client relies on list mode.

---

## Feature list

| ID      | File                                                                                                 | Description                                           |
| ------- | ---------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| 01      | [cursor-dev-01-lambda-estimate-storage.md](cursor-dev-01-lambda-estimate-storage.md)                 | Lambda POST /estimate/storage                         |
| 02      | [cursor-dev-02-lambda-estimate-transfer.md](cursor-dev-02-lambda-estimate-transfer.md)               | Lambda POST /estimate/transfer                        |
| 03      | [cursor-dev-03-lambda-price-storage.md](cursor-dev-03-lambda-price-storage.md)                       | Lambda POST /price-storage                            |
| 04      | [cursor-dev-04-lambda-storage-upload.md](cursor-dev-04-lambda-storage-upload.md)                     | Lambda POST /storage/upload                           |
| 05      | [cursor-dev-05-lambda-storage-ls.md](cursor-dev-05-lambda-storage-ls.md)                             | Lambda GET/POST /storage/ls                           |
| 06      | [cursor-dev-06-lambda-storage-download.md](cursor-dev-06-lambda-storage-download.md)                 | Lambda GET/POST /storage/download                     |
| 07      | [cursor-dev-07-lambda-storage-delete.md](cursor-dev-07-lambda-storage-delete.md)                     | Lambda POST/DELETE /storage/delete                    |
| 08      | [cursor-dev-08-api-gateway-auth.md](cursor-dev-08-api-gateway-auth.md)                               | API Gateway + API key + CORS (CloudFormation/SAM)     |
| 09      | [cursor-dev-09-dynamodb-tables.md](cursor-dev-09-dynamodb-tables.md)                                 | DynamoDB tables (quotes + txn log)                    |
| 10      | [cursor-dev-10-housekeeping-32day.md](cursor-dev-10-housekeeping-32day.md)                           | Housekeeping job (32-day deadline)                    |
| 15      | [cursor-dev-15-cfn-waf.md](cursor-dev-15-cfn-waf.md)                                                 | CloudFormation: WAF                                   |
| 16      | [cursor-dev-16-cfn-observability.md](cursor-dev-16-cfn-observability.md)                             | CloudFormation: Observability                         |
| 17      | [cursor-dev-17-cfn-cloudfront.md](cursor-dev-17-cfn-cloudfront.md)                                   | CloudFormation: CloudFront (optional)                 |
| 18      | [cursor-dev-18-secrets-relayer-key.md](cursor-dev-18-secrets-relayer-key.md)                         | Secrets Manager for relayer private key               |
| 11      | [cursor-dev-11-client-cloud-backup.md](cursor-dev-11-client-cloud-backup.md)                         | Client /mnemospark_cloud backup                       |
| 12      | [cursor-dev-12-client-price-storage.md](cursor-dev-12-client-price-storage.md)                       | Client /mnemospark_cloud price-storage                |
| 13      | [cursor-dev-13-client-upload.md](cursor-dev-13-client-upload.md)                                     | Client /mnemospark_cloud upload                       |
| 14      | [cursor-dev-14-client-ls-download-delete.md](cursor-dev-14-client-ls-download-delete.md)             | Client /mnemospark_cloud ls, download, delete         |
| auth-01 | [cursor-dev-auth-01-lambda-authorizer.md](cursor-dev-auth-01-lambda-authorizer.md)                   | Lambda authorizer (X-Wallet-Signature)                |
| auth-02 | [cursor-dev-auth-02-api-gateway-authorizer.md](cursor-dev-auth-02-api-gateway-authorizer.md)         | API Gateway — remove API key, attach authorizer, CORS |
| auth-03 | [cursor-dev-auth-03-waf-rate-limits.md](cursor-dev-auth-03-waf-rate-limits.md)                       | WAF — rate limits for /price-storage                  |
| auth-04 | [cursor-dev-auth-04-lambdas-authorizer-context.md](cursor-dev-auth-04-lambdas-authorizer-context.md) | Lambdas — authorizer context, no x-api-key            |
| auth-05 | [cursor-dev-auth-05-request-signing-module.md](cursor-dev-auth-05-request-signing-module.md)         | Request signing module (X-Wallet-Signature)           |
| auth-06 | [cursor-dev-auth-06-proxy-wallet-signature.md](cursor-dev-auth-06-proxy-wallet-signature.md)         | Proxy — remove API key, add X-Wallet-Signature        |
| auth-07 | [cursor-dev-auth-07-client-docs-error-handling.md](cursor-dev-auth-07-client-docs-error-handling.md) | Client/docs — remove API key, 401/403 errors          |
| 19      | [cursor-dev-19-workflow-upload-delete-cron-id.md](cursor-dev-19-workflow-upload-delete-cron-id.md)   | Workflow doc upload/delete order + meta_docs cron-id  |
| 20      | [cursor-dev-20-client-upload-delete-workflow.md](cursor-dev-20-client-upload-delete-workflow.md)     | Client upload/delete workflow (cron job + cron-id)    |
| 21      | [cursor-dev-21-docs-object-key-terminology.md](cursor-dev-21-docs-object-key-terminology.md)         | Docs: standardize on object-key (remove s3-key)       |
| 22      | [cursor-dev-22-client-proxy-object-key-terminology.md](cursor-dev-22-client-proxy-object-key-terminology.md) | Client/proxy: object-key in help and user-facing text |
| 23      | [cursor-dev-23-backend-verify-object-key-only.md](cursor-dev-23-backend-verify-object-key-only.md)     | Backend: verify object_key only (no changes expected) |
| 26      | [cursor-dev-26-mnemospark_wallet-command-and-env.md](cursor-dev-26-mnemospark_wallet-command-and-env.md) | Client: /mnemospark_wallet, /mnemospark_cloud, MNEMOSPARK_WALLET_KEY, resolution order |
| 27      | [cursor-dev-27-docs-wallet-command-and-env.md](cursor-dev-27-docs-wallet-command-and-env.md)           | Docs: mnemospark command structure — wallet, cloud, env (depends on 26) |
| 28      | [cursor-dev-28-backend-verify-wallet-migration.md](cursor-dev-28-backend-verify-wallet-migration.md)   | Backend: verify command-structure migration does not break APIs (depends on 26) |
| 48      | [cursor-dev-48-backend-storage-ls-s3-list-mode.md](cursor-dev-48-backend-storage-ls-s3-list-mode.md) | Backend: `/storage/ls` S3 list mode (`object_key` optional); extends 05        |
| 49      | [cursor-dev-49-mnemospark-client-storage-ls-list-friendly-names.md](cursor-dev-49-mnemospark-client-storage-ls-list-friendly-names.md) | Client: wallet-only `ls`, list response, SQLite friendly names, human-readable sizes (depends on 48) |
