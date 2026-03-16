# Cursor Dev: mnemospark Skill Authoring for Main-Agent Operability

**ID:** cursor-dev-45  
**Repo:** mnemospark-docs

**Workspace for Agent:** Work only in **mnemospark-docs**. Create skill design/spec and operator docs only in this repo.

## Scope

Depends on **cursor-dev-44**.

Create a formal mnemospark skill specification so the main OpenClaw agent can reliably run mnemospark commands and understand state/log files.

Deliverables:
- Skill authoring docs under `ops/` and/or `dev_docs/` describing:
  - command catalog (`/mnemospark-cloud`, `/mnemospark-wallet`, async operation status commands)
  - required local file paths
  - SQLite schema references and lookup patterns
  - JSONL event stream references and triage workflows
  - escalation/rollback behaviors
- Draft SKILL.md-style structure aligned to OpenClaw creating-skills guidance.
- Example prompts/task strings for main agent to invoke mnemospark agent reliably.

## References

- OpenClaw creating-skills docs: https://docs.openclaw.ai/tools/creating-skills
- OpenClaw subagents docs: https://docs.openclaw.ai/tools/subagents
- `mnemospark-docs/ops/mnemospark-implementation-order-sqlite-jsonl-subagent-skill.md`

## Agent

- **Install (idempotent):** None.
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] Skill spec clearly documents command usage and async orchestration expectations.
  - [ ] File/db/log locations and troubleshooting semantics are explicit.
  - [ ] Includes concrete runbook examples for main-agent handoff and user updates.
  - [ ] Documentation reviewed for consistency with existing mnemospark docs terminology.
  - [ ] Branch from `main`, open PR.

## Task string (optional)

Author a production-ready mnemospark skill spec in mnemospark-docs so the main OpenClaw agent can delegate and monitor mnemospark operations consistently.


## Decision constraints
- Skill artifacts must live in the `mnemospark` repo and be installable during mnemospark install flow (single-step install).
