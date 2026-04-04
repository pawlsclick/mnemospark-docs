## `meta_docs/` — runtime and flow specs

The `meta_docs/` directory holds **runtime behavior and flow-level specs** for the working mnemospark system:

- Command-centric process flows for the cloud commands:
  - `cloud-backup-process-flow.md`
  - `cloud-price-storage-process-flow.md`
  - `cloud-upload-process-flow.md`
  - `cloud-ls-process-flow.md`
  - `cloud-download-process-flow.md`
  - `cloud-delete-process-flow.md`
  - `cloud-help-process-flow.md`
  - `wallet-and-export-process-flow.md`
- Cross-cutting behavior specs:
  - `cloud-async-orchestrator-modes.md` (`async:true` — `orchestrator:inline` vs `orchestrator:subagent`, timeouts, cancellation)
  - `wallet-proof.md` (wallet proof / `X-Wallet-Signature`)
  - `payment-authorization-eip712-trace.md` (x402 payment header and backend expectations)
  - `backend-api-base-url.md` (how the proxy finds the backend)
  - `backend-logs.md` (where to look in CloudWatch)
  - Troubleshooting (`troubleshoot-price-storage-flow.md`)
- Identifier/reference docs:
  - `ethereum-wallet-generation.md` (viem: how EVM wallet keys are generated on the client)
  - `cron-id-usage.md` (`<cron-id>` for storage payment jobs)
  - `quote-id-dynamodb.md` (`quote_id` in the quotes table)
  - `trans-id-payment-settement.md` (`trans_id` from payment settlement)
- Milestone snapshots:
  - `e2e-staging-milestone-2026-03-16.md` (first full staging e2e: backup → quote → upload → ls → download → hash match)

These docs describe **actual, running behavior** of the mnemospark + mnemospark-backend pair and are kept in sync with known-good milestones.

---

## Conventions

- **Metadata header**
  - Each spec starts with:
    - `Date` (ISO, e.g. `2026-03-16`)
    - `Revision` (e.g. `rev 1`)
    - `Milestone` (e.g. `e2e-staging-2026-03-16`)
    - `Repos / components` (which repo and subsystem it covers)
  - When behavior changes, bump `Revision` and update `Date`. If the change corresponds to a new code tag, update `Milestone` or add a new milestone doc.

- **Structure**
  - Process docs generally use:
    - `## Overview` / introductory paragraph
    - `## Command Overview` (for CLI/command flows)
    - `## Step-by-Step Flow` with subsections for **Client**, **Proxy**, **Backend**
    - `## Files Used Across the Path`
    - `## Logging`, `## Success`, `## Failure Scenarios`
    - One or more **mermaid diagrams** under `## Sequence Diagram` / `## Diagrams`
  - Narrow reference docs (IDs, logs, etc.) just use concise sections (`What`, `Where used`, `How generated`).

- **Mermaid diagrams**
  - Any non-trivial process (multi-step or multi-component) should have at least one mermaid diagram:
    - Sequence diagrams for flows (client → proxy → backend → AWS).
    - Flowcharts where linear data dependencies are easier to see.
  - Follow the same styling used in existing specs (no custom colors; IDs without spaces).

- **Spec references and raw URLs**
  - Each spec ends with a `## Spec references` section that lists:
    - The doc itself (`meta_docs/<file>.md`) and its **raw GitHub URL**:
      - `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/<file>.md`
    - Closely related specs (e.g. upload ↔ payment-authorization, wallet-proof; delete ↔ cron-id-usage).
    - The current milestone overview (`e2e-staging-milestone-2026-03-16.md`) when relevant.
  - When you add a new spec here, add a `## Spec references` section with at least:
    - Self link + raw URL
    - Any directly-related specs

---

## How to update these files

1. **Start from the current milestone**
   - Treat `e2e-staging-milestone-2026-03-16.md` as the baseline description of the working end-to-end system.
   - When you land a change that affects runtime behavior (new route, changed auth, changed flow), either:
     - Update the existing milestone spec to point to a new tag, or
     - Add a new milestone doc and cross-link it.

2. **Keep behavior and code in lockstep**
   - When you change mnemospark or mnemospark-backend behavior:
     - Update the relevant process spec(s) in `meta_docs/`:
       - Parameters, expected responses, error codes.
       - Logging behavior and identifiers.
       - Any diagrams that would become stale.
     - Bump the `Revision` and `Date` fields at the top of each updated spec.
   - Prefer updating the **narrowest** spec that fully captures the change, then adjust the milestone overview if the e2e story changes.

3. **Add new specs when behavior is non-trivial**
   - If you introduce a new command, endpoint, or cross-cutting behavior:
     - Create a new `meta_docs/<feature>-process-flow.md` (or similar) file.
     - Follow the conventions above (metadata, structure, diagrams, spec references).
     - Link it from `e2e-staging-milestone-*.md` once it participates in a validated end-to-end path.

4. **Use raw URLs for agents and scripts**
   - When writing cursor-dev specs or other agent-focused docs, always reference `meta_docs` specs using the **raw URL** form so tools can fetch them directly:
     - `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/<file>.md`

---

## Relationship to other docs

- `product_docs/` holds higher-level PRDs, product specs, and API descriptions.
- `meta_docs/` is **runtime-oriented**: it shows exactly how the commands, proxy, backend, and AWS resources interact at a given milestone.
- `dev_docs/` contains Cursor Agent task specs and templates that often **reference** `meta_docs` as canonical behavior.

