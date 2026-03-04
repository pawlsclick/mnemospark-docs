# mnemospark-docs — single source of truth for docs

This repo is the **canonical documentation** for mnemospark and mnemospark-backend. The code repos no longer embed this repo as a `.company` Git submodule; instead, contributors work directly in **mnemospark-docs**. Edit docs only here (or in a clone of this repo); do not duplicate or maintain copies of these docs inside mnemospark or mnemospark-backend.

---

This directory holds the main product, workflow, and backend documentation for **mnemospark** (storage orchestration for OpenClaw and its agents, with x402 payment-as-authentication).

## Core documents

| Doc                                                                                              | Description                                                                                                                         |
| ------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| [mnemospark_product_spec_v3.md](./product_docs/mnemospark_product_spec_v3.md)                     | Product specification v3: x402, S3, client-held encryption, MVP scope.                                                              |
| [mnemospark_PRD.md](./product_docs/mnemospark_PRD.md)                                             | Product requirements document: problem, goals, requirements (R1–R14), success metrics.                                              |
| [mnemospark_full_workflow.md](./product_docs/mnemospark_full_workflow.md)                         | End-to-end workflow: commands (`/cloud`, `/wallet`), client/proxy/backend steps, canonical source for slash commands and arguments. |
| [mnemospark_backend_api_spec.md](./product_docs/mnemospark_backend_api_spec.md)                   | Backend REST API: endpoints, auth, request/response, idempotency, error codes.                                                      |
| [wallet_gen_payment_eip712.md](./product_docs/wallet_gen_payment_eip712.md) | EIP-712 payment flow and wallet/signing for x402 (Base/USDC).                                                                       |

## Directories

| Directory                                          | Contents                                                                                                                                               |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [infrastructure_design/](./infrastructure_design/) | AWS design for securing the internet-facing backend (API Gateway, WAF, CloudFront, etc.).                                                              |
| [dev_docs/](./dev_docs/)                           | Development-focused docs: Cursor Cloud Agent feature specs, devops features, fix workflows, templates, and tests.                                      |
| [knowledge/](./knowledge/)                         | Reference material: agentic AI best practices, Antfarm notes.                                                                                          |
| [archive/](./archive/)                             | Superseded and design-phase root-level docs (older product specs, Q&A, encryption options, etc.). See [archive/README.md](./archive/README.md).        |

## Testing and proof of functionality

**Required linters (CI):** ESLint (`src/`), Prettier (check), TypeScript (typecheck). See [mnemospark_PRD.md](./product_docs/mnemospark_PRD.md) for success metrics.

| PRD success metric    | How it is proven                                                                                             |
| --------------------- | ------------------------------------------------------------------------------------------------------------ |
| Quote accuracy        | Unit/integration tests (BCM/GetCostForecast + markup).                                                       |
| Time to first store   | E2E with mock backend or manual with real backend.                                                           |
| Plugin adoption       | Install test matrix: `npm run test:install-check` (plugin load after build); full OpenClaw install optional. |
| Retry safety          | API tests (idempotency key, no double charge).                                                               |
| Payment-before-access | Gateway logic + audit/log; optional e2e 402 → pay → 200.                                                     |

**CI runs:** format check, lint, typecheck, **unit tests** (`npm test`), build, **install check** (plugin entry point loads). Integration and full e2e may be run manually or in a separate workflow.
