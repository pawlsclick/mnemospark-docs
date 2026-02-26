# Code cleanup 03: Docs and metadata aligned with PRD

**ID:** cleanup-03  
**Repo:** mnemospark  
**Rough size:** One Cloud Agent run

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). The spec is at `.company/code_cleanup/cleanup-03-docs-metadata.md`.

## Scope

Align **descriptions and metadata** with [mnemospark_PRD.md](../mnemospark_PRD.md). mnemospark is an OpenClaw plugin for **storage + wallet + x402 payment**; it does **not** provide chat or "Smart LLM router."

**Update in mnemospark repo:**

- **package.json:** Change `description` from "Smart LLM router and inference toolkit…" / "30+ models…" to wording that matches the PRD (e.g. OpenClaw plugin for USDC storage and wallet, x402 payment; commands /wallet and /cloud per workflow). Remove any "router" keyword from description.
- **openclaw.plugin.json:** Change `description` to match (no "Smart LLM router", no "30+ models").
- **openclaw.security.json:** Change `description` to match (wallet key for payment signing and storage; no LLM router).
- **README.md:** Update title/description and Quick start (if present) to reflect workflow-only: storage, wallet, x402; reference [mnemospark_full_workflow.md](../mnemospark_full_workflow.md) and PRD. Remove references to "smart routing", "blockrun/auto", "30+ models", or chat.

**Do not:**

- Edit files under `.company` (mnemospark-docs submodule). All doc content that lives in mnemospark-docs stays in that repo; this run only updates in-repo files (package.json, openclaw.*.json, README.md) in mnemospark.

## References

- [mnemospark_PRD.md](../mnemospark_PRD.md) — product description, R8 (plugin, /wallet, /cloud).
- [mnemospark_full_workflow.md](../mnemospark_full_workflow.md) — commands and workflow.
- mnemospark repo: `package.json`, `openclaw.plugin.json`, `openclaw.security.json`, `README.md`.

## Cloud Agent

- **Install (idempotent):** None.
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] package.json description aligned with PRD (storage + wallet + x402; no "Smart LLM router" or "30+ models").
  - [ ] openclaw.plugin.json description aligned with PRD.
  - [ ] openclaw.security.json description aligned with PRD.
  - [ ] README.md describes mnemospark as workflow-only (storage, wallet, x402); no chat or router wording.
  - [ ] No edits under `.company`.
  - [ ] `pnpm build` still passes (no code changes).

## Task string (optional)

Work only in this repo. Align package.json, openclaw.plugin.json, openclaw.security.json, and README with mnemospark PRD: mnemospark = OpenClaw plugin for storage + wallet + x402; no chat, no Smart LLM router. Acceptance: [ ] descriptions match PRD; [ ] pnpm build passes.
