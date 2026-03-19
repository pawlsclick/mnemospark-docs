# Cursor Dev: mnemospark Skill Authoring for Main-Agent Operability

**ID:** cursor-dev-45  
**Repo:** mnemospark-docs

**Workspace for Agent:** Work only in **mnemospark-docs**. Create skill design/spec and operator docs only in this repo.

## Scope

Depends on **cursor-dev-44** and must incorporate the proxy JSONL observability baseline from **cursor-dev-43** (`proxy-events.jsonl` correlation + terminal event semantics).

Create a formal mnemospark skill specification so the main OpenClaw agent can reliably run mnemospark commands and understand state/log files, with an installable skill package that ships with the mnemospark plugin.

Deliverables:
- Skill authoring docs under `ops/` and/or `dev_docs/` describing:
  - command catalog (`/mnemospark_cloud`, `/mnemospark_wallet`, async operation status commands)
  - explicitly document `--async` usage for long-running upload/download and `/mnemospark_cloud op-status --operation-id <id>` behavior
  - include explicit `--name` / `--latest` / `--at` usage and ambiguity handling rules from cursor-dev-42
  - required local file paths
  - SQLite schema references and lookup patterns (including `friendly_names` Option 2 table added by cursor-dev-42 and `operations` lookups for async status)
  - JSONL event stream references and triage workflows (`events.jsonl`, `manifest.jsonl`, `proxy-events.jsonl`)
  - escalation/rollback behaviors
- Draft SKILL.md-style structure aligned to OpenClaw creating-skills guidance.
- Example prompts/task strings for main agent to invoke mnemospark agent reliably.
 - Clear description of where the concrete skill package (SKILL metadata + any helper code) will live in the `mnemospark` repo and how the mnemospark build/install flow bundles it so that installing the mnemospark plugin automatically makes the skill available to OpenClaw (no separate install step).

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

Author a production-ready mnemospark skill spec in mnemospark-docs so the main OpenClaw agent can delegate and monitor mnemospark operations consistently, and describe how the bundled skill package in the `mnemospark` repo is included in the plugin build so it is available to OpenClaw on install.


## Output produced in this docs repo
- `ops/mnemospark-skill-spec.md`

## Decision constraints
- Skill artifacts must live in the `mnemospark` repo and be installable during mnemospark install flow (single-step install).
