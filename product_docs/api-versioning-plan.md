## mnemospark-backend API versioning plan

### Goal

Transition mnemospark-backend from unversioned paths:

- `/price-storage`
- `/storage/upload`
- `/storage/upload/confirm`
- `/storage/ls`
- `/storage/download`
- `/storage/delete`

to versioned paths:

- `/api/v1/price-storage`
- `/api/v1/payment/settle`
- `/api/v1/storage/upload`
- `/api/v1/storage/upload/confirm`
- `/api/v1/storage/ls`
- `/api/v1/storage/download`
- `/api/v1/storage/delete`

without breaking existing clients, and with a clear deprecation window.

---

### Phase 1 – Prep (no behavior change)

- **Inventory**
  - Confirm all public endpoints and methods from `mnemospark-backend/template.yaml` (and any future ones), treating them as **v1 semantics**.
- **Spec & docs**
  - In `mnemospark-backend/docs/openapi.yaml`, add metadata:
    - `info.version: "1.0.0"` (or similar) and a note that current paths represent **v1**.
  - In each endpoint doc (e.g. `price-storage.md`, `storage-upload.md`), add a short **Versioning** section explaining that future releases may introduce `/api/v1/...` equivalents.
- **Client awareness**
  - In the `mnemospark` client repo docs / CHANGELOG, note that a future release will:
    - Add config for a **versioned base path**.
    - Default to the current root for backward compatibility.

---

### Phase 2 – Introduce `/api/v1` alongside existing paths

- **Backend routing**
  - In `mnemospark-backend/template.yaml`:
    - Add **duplicate API events** for all operations with `/api/v1/...` paths pointing at the **same Lambdas**.
    - Keep existing unversioned routes active.
- **Wallet proof & authorizer**
  - Update wallet proof spec and backend authorizer so that:
    - Both `/price-storage` and `/api/v1/price-storage` are treated equivalently for signature validation (normalize by stripping an optional `/api/v1` prefix internally).
    - The same applies for all storage and payment paths.
- **OpenAPI & docs**
  - In `mnemospark-backend/docs/openapi.yaml`:
    - Document **versioned paths** as canonical (tagged `v1`).
    - Optionally mention unversioned paths as **deprecated aliases** in operation descriptions.
  - In endpoint docs, show **versioned URLs** as primary and note unversioned aliases.
- **Client feature flag**
  - Add a config option in the `mnemospark` client:
    - `basePath` or `apiVersionPath` (default `""`, future default `/api/v1`).
  - Update client tests to exercise both base paths.

---

### Phase 3 – Default clients to `/api/v1`

- **Client behavior**
  - Change the default in `mnemospark` (and any proxies/OpenClaw config) to use `/api/v1/...` paths.
  - Keep an **opt-out** flag/environment variable to force legacy root paths for a deprecation window.
- **Monitoring**
  - Use:
    - The `api_calls` DynamoDB table.
    - API Gateway access logs.
  - To track traffic share between:
    - `/price-storage` vs `/api/v1/price-storage`, etc.
  - Define a success threshold (for example, **>95% of traffic on `/api/v1` for 30 days**).

---

### Phase 4 – Deprecate and remove unversioned paths

- **Deprecation signal**
  - After the adoption threshold is met:
    - Mark unversioned paths as **deprecated** in docs and OpenAPI descriptions.
    - Optionally return a custom warning header on unversioned paths (e.g. `Deprecation: true`, `Sunset: <date>`) for a grace period.
- **Removal**
  - Remove unversioned routes from `mnemospark-backend/template.yaml` so only `/api/v1/...` remain.
  - Update wallet proof docs:
    - Show `/api/v1/...` exclusively in `MnemosparkRequest.path` examples.
  - Simplify authorizer path normalization:
    - Treat `/api/v1/...` as canonical; drop special-casing for legacy roots.

---

### Future cursor-dev tasks (high level)

- One cursor-dev file to add **dual routing + authorizer/path normalization**.
- One to update **OpenAPI + endpoint docs** to show `/api/v1`.
- One to **flip client defaults** and add monitoring/telemetry around path usage.
- One to **remove** unversioned paths after the deprecation window expires.

