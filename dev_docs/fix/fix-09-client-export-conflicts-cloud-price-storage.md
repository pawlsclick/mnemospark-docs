# Cursor Dev: Fix export conflicts in cloud-price-storage.ts

**ID:** fix-09  
**Repo:** mnemospark

**Workspace for Agent:** Work only in **this repo** (mnemospark). This repo is the OpenClaw plugin client (wallet, cloud commands, proxy). Do **not** clone or require access to any other repository; all code and references are in this file.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Fix TypeScript export conflicts in `src/cloud-price-storage.ts` that cause CI to fail with:

- `Export declaration conflicts with exported declaration of 'BackendSettleForwardResult'.`
- `Export declaration conflicts with exported declaration of 'BackendSettleOptions'.`
- `Export declaration conflicts with exported declaration of 'ProxySettleOptions'.`

These types are already exported inline in the same file (e.g. `export type BackendSettleOptions = { ... }` around lines 134, 144, 150). They must **not** be listed again in the trailing `export type { ... }` block at the end of the file (around lines 825–836). Remove only `BackendSettleForwardResult`, `BackendSettleOptions`, and `ProxySettleOptions` from that block; leave all other names in the block (they are not exported inline and need the re-export).

After the change, run `npm run typecheck` (and optionally `npm run test`) to confirm the check step passes.

## References

- [GitHub Actions run (failure)](https://github.com/pawlsclick/mnemospark/actions/runs/23105371970) — CI check fails at step 7 with exit code 2 due to these export conflicts.
- `src/cloud-price-storage.ts` — inline exports at ~L134, L144, L150; re-export block at ~L825–836.

## Agent

- **Install (idempotent):** `npm install`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] In `src/cloud-price-storage.ts`, the trailing `export type { ... }` block no longer includes `BackendSettleForwardResult`, `BackendSettleOptions`, or `ProxySettleOptions`.
  - [ ] `npm run typecheck` passes with no errors.
  - [ ] Existing tests still pass (`npm run test`).

## Task string (optional)

Work only in the mnemospark repo. In `src/cloud-price-storage.ts`, remove the three duplicate type names (`BackendSettleForwardResult`, `BackendSettleOptions`, `ProxySettleOptions`) from the final `export type { ... }` block so TypeScript no longer reports "Export declaration conflicts with exported declaration of 'X'". Run `npm run typecheck` and `npm run test` to verify. Open a new branch and PR; do not commit to main.
