# Cursor Dev: Client — Wallet-only `ls`, S3 list response handling, SQLite friendly-name enrichment, `ls -l`-style listing, human-readable sizes

**ID:** cursor-dev-49  
**Repo:** mnemospark  
**Date:** 2026-03-21  
**Revision:** rev 3  
**Last commit in repo (when authored):** `2c1d804` — chore: sync release-please manifest to 0.2.2 (#55)  

**Depends on:** **cursor-dev-48** (mnemospark-backend: `/storage/ls` list mode **deployed** or available in the target environment). Do not merge client-only changes that **require** list mode until the backend supports it; alternatively implement **backward-compatible** parsing (handle both single-object and list responses) and gate wallet-only `ls` on detecting list support (not preferred—deploy backend first).

**Workspace for Agent:** Work only in **mnemospark**. Do **not** edit mnemospark-backend in this run; consume the API contract from cursor-dev-48 / backend OpenAPI. Primary spec: this file (raw: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/dev_docs/features_cursor_dev/cursor-dev-49-mnemospark-client-storage-ls-list-friendly-names.md`).

**AWS:** Client does not call AWS APIs directly for this feature; storage calls go through the **proxy → backend**. Use **AWS MCP** only if you need to confirm S3 or IAM semantics for documentation strings or troubleshooting (optional).

---

## Order of operations (all repos)

1. **cursor-dev-48 (mnemospark-backend)** — merged, stack **deployed** with list mode on `/storage/ls`.
2. **This task (cursor-dev-49, mnemospark)** — parser, `cloud-storage.ts`, `proxy.ts` if needed, `cloud-command.ts` user messages, `cloud-datastore.ts` lookup helper, tests.
3. **mnemospark-docs (optional)** — update [mnemospark_full_workflow.md](../product_docs/mnemospark_full_workflow.md) or slash-command help if `ls` examples still say `--object-key` is mandatory.

---

## Scope

### 1. Command-line / parser (`src/cloud-command.ts`)

- For subcommand **`ls` only**, allow **`--wallet-address`** without **`--object-key`** and without **`--name`** (today `parseObjectSelector` returns `null` if both are missing — change this **only for `ls`**).
- **`download`** and **`delete`** must **continue to require** an object selector (`--object-key` or `--name` + selectors) — do not widen accidentally.
- When in **list mode**, build a storage request payload that **omits** `object_key` (or sends explicit null only if backend accepts it; prefer omission to match GET query behavior).
- Update in-app / slash help strings that currently imply `--object-key` or `--name` is always required for `ls`.

### 2. HTTP client and types (`src/cloud-storage.ts`)

- Extend **`StorageLsResponse`** (or introduce a discriminated union) to represent:
  - **Stat:** existing single-object shape.
  - **List:** `list_mode: true`, `objects: Array<{ key: string; size_bytes: number; last_modified?: string }>`, plus pagination fields mirroring backend (`is_truncated`, `next_continuation_token`).
- Harden **`parseLsResponse`** (or equivalent) to validate both shapes; throw clear errors on malformed payloads.
- **`requestStorageLs`** (or the function that POSTs to `/storage/ls`) must forward optional pagination parameters when exposing advanced usage (MVP: single page; optional CLI flags `--max-keys` / `--continuation-token` can be a follow-up).

### 3. Proxy (`src/proxy.ts`)

- Ensure the proxy forwards **POST** bodies / **GET** queries **without** `object_key` when in list mode (no middleware that strips empty fields incorrectly).

### 4. SQLite — best-effort friendly names (`src/cloud-datastore.ts`)

Add a helper, e.g. **`findLatestFriendlyNameForObjectKey(walletAddress: string, objectKey: string): Promise<string | null>`**, with this **resolution order**:

1. **`friendly_names`**: `wallet_address` match, `object_key = ?`, `is_active = 1`, order by **`created_at` DESC**, limit **1**.
2. Else **`objects`** by `object_key` → `object_id`, then **`friendly_names`** by `object_id` + wallet + `is_active = 1`, latest `created_at`.

If no row: return **`null`** (UI shows key only or “unnamed”).

**Note:** S3 is authoritative for **which keys exist**; SQLite only **labels** keys when data exists locally.

### 5. User-facing output (`cloud-command.ts` or small formatter)

- After any **bucket / disclaimer** lines (see below), render **`ls` output in a GNU `ls -l`-style column layout** — **one line per object**, stable left-to-right columns, **space-padded** so sizes and dates line up when the client lists **multiple** objects (compute column widths from the **full result set** before printing, like a fixed-font table).
- **Disclaimer (unchanged):** before the listing, keep a **short** note that **friendly names** come from the **local SQLite catalog** and may be missing for some keys.

### 5a. `ls -l`-style columns (stat and list `ls`)

Match the **visual habit** of **`ls -l`**: permission-like field, link count, owner, group, **size**, **date**, **name** (see [GNU `ls` long format](https://www.gnu.org/software/coreutils/manual/html_node/ls-invocation.html)).

**Column order (left → right)**

1. **Mode / type (10 chars):** literal **`----------`** (placeholder only; **no** Unix permission semantics for S3 objects).
2. **Link count:** literal **`1`** (fixed width **2**, right-aligned: ` 1`).
3. **Owner:** literal **`-`** (fixed width **8**, left-aligned padded).
4. **Group:** literal **`-`** (fixed width **8**, left-aligned padded).
5. **Size:** human-readable size from **§5b** (below), **right-aligned** in a column whose width = **max rendered width** across all rows in this response **+ 1** leading space before the date (same role as `ls -l` size field).
6. **Date / time:** derived from S3 `last_modified` when present. Use the same **shape** as `ls -l`: **`MMM DD HH:MM`** for “recent” objects and **`MMM DD  YYYY`** (or equivalent fixed width) for older years — pick one rule and document it in code (e.g. same calendar year as “now” → time; else year). Use **UTC** or **local** time but **state which** in a one-line comment. If `last_modified` is missing, use a **fixed-width** placeholder **`         -`** (12 chars) so columns stay aligned.
7. **Name:** last column, unbounded width. If a friendly name exists: **`Friendly name (object_key)`**; else **`object_key`**. Do not pad the name column; long names may extend past other rows (same as `ls -l` with long filenames).

**Single-object (stat) `ls`**

- Emit **one** line in the **same** column layout (synthetic single-row table) so stat and list look consistent.

**Optional first line (list mode only)**

- If useful, print **`total <N>`** on its own line before the rows, where **`<N>`** is the **number of objects** in this response (not disk blocks). If pagination truncates the bucket, append a clear line such as **`... (truncated; more objects in bucket)`** when the backend indicates truncation.

**Tests**

- Golden-string or structural tests: **multiple objects** share the **same** width for the **size** and **date** columns; each line contains the **10-char** mode placeholder and **object key** text.

### 5b. Human-readable file sizes (stat and list `ls`)

Today `ls` surfaces **`size_bytes`** in a way that is hard to scan. **Change user-visible output** to show an **easy-to-read size** with **KB / MB / GB** (and **B** for small files, **TB** if needed). The resulting strings populate the **size column** in **§5a**.

**Requirements**

- Apply to **both** modes: existing **single-object** `ls` (stat) and new **list** `ls`.
- Implement a **single shared helper**, e.g. `formatBytesForDisplay(bytes: number): string` (name to match repo conventions), colocated with existing storage message formatters or in `cloud-utils.ts` if that is the right shared home. **Reuse** if an equivalent already exists.
- **Input:** non-negative integer (floor or reject non-integers / NaN per existing error style). **`0`** must display as **`0 B`**.
- **Scale:** use **decimal** prefixes (1 KB = **1_000** B, 1 MB = **1_000_000** B, etc.) and labels **`B`**, **`KB`**, **`MB`**, **`GB`**, **`TB`**. This matches common “SI” storage labeling users expect when they say “MB/GB.”
- **Precision:** use **at most one decimal place** for KB+ when the fractional part matters; prefer **whole numbers** when the value is within **1%** of the next unit boundary (avoid `1023.9 KB` when `1.0 MB` is clearer). Trim trailing **`.0`**. Document the rounding rule in a one-line comment next to the helper.
- **API contract:** backend continues to return **`size_bytes` only** (see cursor-dev-48); do not rely on formatted strings from the server.

**Tests**

- Unit tests for the formatter: `0`, values just below/above 1_000 and 1_000_000, large objects, and typical list rows.

### 6. Operations / telemetry

- Prefer **one** `operations` row per `ls` list invocation (`type: "ls"`, metadata or error_message field noting `list_mode: true`) rather than one row per S3 key (avoid SQLite spam).

### 7. Tests

- Update tests that expect **`ls` + wallet only** to be invalid (`src/cloud-command.test.ts` in the mnemospark repo currently asserts invalid args).
- Add unit tests for **parse** (list mode), **response parsing**, and **friendly name resolution** (datastore).
- **`cloud-storage.test.ts`**: fixture for list response.
- **User message / integration-style tests:** assert `ls` output contains **formatted sizes** (not only raw `size_bytes` integers) for stat and list flows where applicable.
- Assert **`ls -l`-style layout**: multiple objects produce **aligned** columns; lines include the **10-char** placeholder mode field and **consistent** size-column width.

---

## Overview

End users run `/mnemospark_cloud ls --wallet-address <addr>` and see **every object key** in their bucket (from S3 via the backend), with **friendly names** filled in when the local SQLite `friendly_names` / `objects` tables have a match. **All `ls` output** (single-object and list) uses a **GNU `ls -l`-like column layout** (placeholder mode, size, date, name) with **human-readable sizes** (B, KB, MB, GB, …) instead of raw byte counts alone.

---

## Context

- SQLite schema: `friendly_names` includes `friendly_name`, `object_id`, `object_key`, `wallet_address`, `is_active`, `created_at` (see mnemospark `src/cloud-datastore.ts`).
- Backend contract: **cursor-dev-48**.

---

## Diagrams

```mermaid
sequenceDiagram
  autonumber
  participant User
  participant Cmd as cloud-command
  participant DS as cloud-datastore SQLite
  participant Proxy as mnemospark proxy
  participant API as Backend /storage/ls

  User->>Cmd: ls --wallet-address 0x...
  Cmd->>Proxy: POST /storage/ls (no object_key)
  Proxy->>API: forward signed request
  API-->>Proxy: list_mode + objects[]
  Proxy-->>Cmd: JSON
  loop For each S3 key
    Cmd->>DS: findLatestFriendlyNameForObjectKey(wallet, key)
    DS-->>Cmd: friendly name or null
  end
  Cmd-->>User: ls -l-style lines (columns + human size + mtime + name)
```

---

## References

- This spec: [cursor-dev-49-mnemospark-client-storage-ls-list-friendly-names.md](cursor-dev-49-mnemospark-client-storage-ls-list-friendly-names.md) — raw: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/dev_docs/features_cursor_dev/cursor-dev-49-mnemospark-client-storage-ls-list-friendly-names.md`
- Backend dependency: [cursor-dev-48-backend-storage-ls-s3-list-mode.md](cursor-dev-48-backend-storage-ls-s3-list-mode.md)
- Prior client ls: [cursor-dev-14-client-ls-download-delete.md](cursor-dev-14-client-ls-download-delete.md)
- Backend OpenAPI (contract): `https://raw.githubusercontent.com/pawlsclick/mnemospark-backend/refs/heads/main/docs/openapi.yaml`
- GNU coreutils `ls` long listing (reference for column order): [ls invocation](https://www.gnu.org/software/coreutils/manual/html_node/ls-invocation.html)

---

## Agent

- **Install (idempotent):** `npm ci` or `npm install` per project.
- **Start (if needed):** None; mock `fetch` in tests.
- **Secrets:** None for unit tests.
- **Acceptance criteria (checkboxes):**
  - [ ] `/mnemospark_cloud ls --wallet-address <addr>` **without** `--object-key` or `--name` is **valid** and triggers **list mode**.
  - [ ] **download** / **delete** still **require** object selector.
  - [ ] **Proxy** forwards list requests without forcing `object_key`.
  - [ ] **Response parsing** supports **both** stat and list JSON shapes from backend.
  - [ ] **SQLite helper** resolves friendly name with the **two-step** rule (`object_key` row first, then `object_id`).
  - [ ] **User-visible output** shows S3 keys with **best-effort** names and a **short disclaimer** about local catalog.
  - [ ] **`ls` shows human-readable sizes** (B, KB, MB, GB, TB as needed) for **both** stat and list modes via a **shared** `formatBytesForDisplay` (or equivalent), using **decimal** KB/MB/GB; **unit tests** cover edge cases.
  - [ ] **List (and stat) `ls` output matches `ls -l`-style columns** per **§5a** (placeholder mode, links, owner, group, right-aligned size, fixed-width date, name last).
  - [ ] **Tests** updated/added; CI green.
  - [ ] Branch + PR from default branch (follow mnemospark repo policy if documented).

---

## Task string (optional)

Work only in **mnemospark**. Read `cursor-dev-49-mnemospark-client-storage-ls-list-friendly-names.md` in mnemospark-docs (raw GitHub URL if needed). **Depends on deployed cursor-dev-48.** Implement wallet-only `ls`: relax `parseObjectSelector` for `ls` only; extend `cloud-storage` types and parsers for list responses; add `findLatestFriendlyNameForObjectKey` in `cloud-datastore.ts`; format output as **GNU `ls -l`-style column rows** (§5a) with **shared human-readable byte formatting** (§5b) for **both** stat and list `ls`; disclaimer before listing; optional `total N` + truncation line; update proxy if needed; fix tests that treat wallet-only `ls` as invalid. Do not change download/delete selector requirements. Acceptance: spec checkboxes.
