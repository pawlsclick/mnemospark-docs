# mnemospark Skill Spec (Main-Agent Operability)

Status: Draft for cursor-dev-45  
Repo: `mnemospark-docs`  
Depends on: cursor-dev-42, cursor-dev-43, cursor-dev-44

## 1) Purpose

Define a production-ready `mnemospark` AgentSkill contract so OpenClaw’s main agent can:
- run mnemospark cloud workflows safely,
- delegate long-running work asynchronously,
- troubleshoot using SQLite + JSONL observability,
- and provide clear user-facing updates.

---

## 2) Skill Packaging Plan (in `mnemospark` repo)

The concrete skill package should live in the **mnemospark plugin repo** at:

- `skills/mnemospark/SKILL.md` (entrypoint)
- `skills/mnemospark/references/` (operator references)
- `skills/mnemospark/scripts/` (optional helper scripts)

### Install-time bundling (single-step)
When user runs:
- `openclaw plugins install mnemospark@latest`

The plugin install process must place or expose `skills/mnemospark/` so OpenClaw can discover it without separate manual install.

Expected operator experience:
1. Install plugin
2. Restart gateway
3. Skill is available

---

## 3) Command Catalog (what the skill orchestrates)

## `/mnemospark_cloud`

### Core
- `backup <file|directory> [--name <friendly-name>]`
- `price-storage --wallet-address <addr> --object-id <id> --object-id-hash <hash> --gb <gb> --provider <provider> --region <region>`
- `upload --quote-id <quote-id> --wallet-address <addr> --object-id <id> --object-id-hash <hash> [--name <friendly-name>] [--async]`
- `ls --wallet-address <addr> [--object-key <object-key> | --name <friendly-name>] [--latest|--at <timestamp>]`
- `download --wallet-address <addr> [--object-key <object-key> | --name <friendly-name>] [--latest|--at <timestamp>] [--async]`
- `delete --wallet-address <addr> [--object-key <object-key> | --name <friendly-name>] [--latest|--at <timestamp>]`
- `op-status --operation-id <id>`

### Name resolution rules
- `--object-key` and `--name` are mutually exclusive.
- If `--name` maps to multiple objects and neither `--latest` nor `--at` is present, return ambiguity error.
- Name resolution is SQLite-first (`friendly_names`), not JSONL parsing.

## `/mnemospark_wallet`
- wallet inspection/export and setup support per existing mnemospark wallet command behavior.

---

## 4) Async Orchestration Contract (main agent -> mnemospark)

For long-running actions (`upload`, `download`):
1. Prefer `--async`.
2. Return immediate user response containing `operation-id`.
3. Poll with `op-status --operation-id <id>` at reasonable intervals.
4. Send user progress/final state updates.

Terminal states:
- `succeeded`
- `failed` (include `error-code`/`error-message` when present)

Fallback behavior:
- If SQLite unavailable, `op-status` may return `Operation not found: <id>`.
- Skill should communicate this clearly and propose next action (retry once SQLite restored, inspect logs).

---

## 5) Local State + File Paths

Primary paths:
- `~/.openclaw/mnemospark/state.db`
- `~/.openclaw/mnemospark/events.jsonl`
- `~/.openclaw/mnemospark/manifest.jsonl`
- `~/.openclaw/mnemospark/proxy-events.jsonl`
- Legacy compatibility paths:
  - `~/.openclaw/mnemospark/object.log`
  - `~/.openclaw/mnemospark/crontab.txt`

---

## 6) SQLite lookup patterns the skill should know

Tables used by skill flows:
- `objects`
- `payments`
- `cron_jobs`
- `operations`
- `friendly_names`

Minimum query intents:
- Resolve friendly name -> object key (`friendly_names`)
- Read operation lifecycle (`operations`)
- Inspect quote/payment/object linkage (`objects` + `payments`)

---

## 7) JSONL triage model

- `events.jsonl`: client operation events
- `manifest.jsonl`: friendly-name mapping/audit events
- `proxy-events.jsonl`: proxy-side correlated events (`trace_id`, `operation_id`, terminal events)

Guiding rule: logs are best-effort and should not break command success paths.

---

## 8) Escalation / rollback playbook (skill behavior)

Escalate when:
- repeated `failed` terminal operations with same error signature,
- payment settle and upload paths diverge repeatedly,
- name resolution ambiguity persists despite selectors.

Rollback/safe fallback:
- use direct `--object-key` when name resolution is uncertain,
- switch to synchronous command without `--async` for one-off validation,
- verify wallet/proxy health before retry storms.

---

## 9) Draft SKILL.md structure (for `mnemospark` repo)

```md
# mnemospark

## When to use
Use for mnemospark cloud backup/storage flows, quote/upload/download/delete, async operation tracking, and wallet-aware troubleshooting.

## Inputs expected
- user intent (backup/upload/download/delete/status)
- wallet context
- optional friendly name selectors

## Execution rules
1. Prefer safe parse + validation of required args.
2. For long operations, prefer --async and return operation-id.
3. Use op-status for follow-up until terminal state.
4. Use SQLite first for name/operation state, JSONL for trace context.
5. If SQLite unavailable, report graceful fallback and next action.

## References
- references/commands.md
- references/state-and-logs.md
- references/troubleshooting.md
```

---

## 10) Example prompts/task strings for main agent

- "Run `/mnemospark_cloud backup /path/to/dir --name \"Quarterly Notes\"`, then quote storage and prepare upload command."
- "Start async upload with `/mnemospark_cloud upload ... --async` and report the operation ID immediately."
- "Check operation progress using `/mnemospark_cloud op-status --operation-id <id>` and summarize for user."
- "Resolve `--name ProjectAlpha --latest` and download to local workspace asynchronously."
- "Troubleshoot failed upload by correlating `operations` row with `events.jsonl` and `proxy-events.jsonl`."

---

## 11) Review checklist (cursor-dev-45 acceptance)

- [x] Command catalog includes async + op-status behavior.
- [x] Name-selector rules are explicit.
- [x] SQLite + JSONL paths and semantics documented.
- [x] Skill packaging/bundling plan in mnemospark repo documented.
- [x] Example prompts for reliable main-agent invocation included.
