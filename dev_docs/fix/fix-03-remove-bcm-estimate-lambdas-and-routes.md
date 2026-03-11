# Cursor Dev: Remove BCM Estimate Lambdas and Routes

**ID:** fix-03-remove-bcm-estimate-lambdas-and-routes  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. It contains the AWS SAM template, backend Lambda handlers (including `/price-storage` and the estimate Lambdas), and tests. Do **not** clone, or require access to any other repository; all code and references are in this file. References: see **References** section below.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Cleanly decommission the **BCM Pricing Calculator–based estimate Lambdas** and their API routes (`/estimate/storage` and `/estimate/transfer`) now that `/price-storage` uses the AWS Price List Query API directly.

This fix **depends on**:

- `fix-01-price-list-price-storage-lambda` (new Price List–based `/price-storage` implementation is in place).
- `fix-02-price-list-iam-and-config` (IAM is correctly configured for the new implementation).

Concretely:

- In `template.yaml`:
  - Remove the **EstimateStorageFunction** and **EstimateTransferFunction** resources:
    - Delete their `AWS::Serverless::Function` resource definitions, including:
      - `Handler` and `CodeUri` settings (currently pointing into `services/estimate-storage` and `services/estimate_transfer_entry.py`).
      - All `Events` definitions for:
        - `GET /estimate/storage`
        - `POST /estimate/storage`
        - `GET /estimate/transfer`
        - `POST /estimate/transfer`
      - Any attached IAM `Policies` that grant BCM Pricing Calculator and STS permissions for these functions specifically.
  - Remove any **CloudWatch Logs** log group resources and Outputs specific to these Lambdas, for example:
    - `EstimateStorageFunctionLogGroup` / `EstimateTransferFunctionLogGroup`.
    - Outputs like `EstimateStorageFunctionArn` and `EstimateTransferFunctionArn` if present.
  - Ensure that no remaining parts of the template reference the removed resources (including `Outputs`, alarms, or cross-resource references).

- In `services/`:
  - Remove (or mark as dead code if you intentionally want to keep them for historical reasons) the following files, ensuring they are no longer imported by any live code paths:
    - `services/estimate-storage/app.py`
    - `services/estimate-transfer/app.py`
    - `services/estimate_transfer_entry.py`
  - Before deletion, search for references across the repo to confirm that no other Lambda or module imports these (`import estimate-storage`/`estimate-transfer` or `_load_service_module(..., "estimate-storage")` etc.). The `/price-storage` Lambda should already have been refactored in `fix-01` to no longer rely on these modules.

- In tests:
  - Update the test suite to reflect the removal of these endpoints and Lambdas:
    - Remove or refactor tests that explicitly target `/estimate/storage` or `/estimate/transfer`, which likely live in:
      - `tests/unit/test_estimate_storage.py`
      - `tests/unit/test_estimate_transfer.py`
      - `tests/integration/test_estimate_storage_integration.py`
      - `tests/integration/test_estimate_transfer_integration.py`
    - Ensure that remaining tests do not reference the now-removed resources or endpoints.
    - Confirm that the overall pricing behavior is still covered via `/price-storage` tests (unit and integration), not the deprecated estimate endpoints.

- After the code and template changes:
  - Run the project’s test suite (unit + integration where feasible).
  - Run `sam validate` to ensure the template remains correct.
  - Optionally deploy to a staging stack and verify:
    - `/price-storage` continues to function as expected.
    - `/estimate/storage` and `/estimate/transfer` endpoints are no longer present or callable.

## References

- High-level description of the price-storage flow and how estimate services were previously used:
  - [mnemospark-docs/meta_docs/cloud-price-storage-process-flow.md](../../../mnemospark-docs/meta_docs/cloud-price-storage-process-flow.md)
- Backend SAM template defining Lambdas and API routes (including estimate and price-storage functions):
  - [mnemospark-backend/template.yaml](../../../mnemospark-backend/template.yaml)
- Price-storage implementation (should already be using Price List Query API after `fix-01`):
  - [mnemospark-backend/services/price-storage/app.py](../../../mnemospark-backend/services/price-storage/app.py)
  - [mnemospark-backend/services/price_storage_entry.py](../../../mnemospark-backend/services/price_storage_entry.py)
- BCM-based estimate modules to be decommissioned:
  - [mnemospark-backend/services/estimate-storage/app.py](../../../mnemospark-backend/services/estimate-storage/app.py)
  - [mnemospark-backend/services/estimate-transfer/app.py](../../../mnemospark-backend/services/estimate-transfer/app.py)
  - [mnemospark-backend/services/estimate_transfer_entry.py](../../../mnemospark-backend/services/estimate_transfer_entry.py)
- Tests that currently exercise estimate endpoints (to be cleaned up or removed):
  - [mnemospark-backend/tests/unit/test_estimate_storage.py](../../../mnemospark-backend/tests/unit/test_estimate_storage.py)
  - [mnemospark-backend/tests/unit/test_estimate_transfer.py](../../../mnemospark-backend/tests/unit/test_estimate_transfer.py)
  - [mnemospark-backend/tests/integration/test_estimate_storage_integration.py](../../../mnemospark-backend/tests/integration/test_estimate_storage_integration.py)
  - [mnemospark-backend/tests/integration/test_estimate_transfer_integration.py](../../../mnemospark-backend/tests/integration/test_estimate_transfer_integration.py)
- Price-storage tests that should remain and provide pricing coverage:
  - [mnemospark-backend/tests/unit/test_price_storage.py](../../../mnemospark-backend/tests/unit/test_price_storage.py)
  - [mnemospark-backend/tests/integration/test_price_storage_integration.py](../../../mnemospark-backend/tests/integration/test_price_storage_integration.py)

## Agent

- **Install (idempotent):**  
  `pip install -r requirements.txt`

- **Start (if needed):**  
  None.

- **Secrets:**  
  None required for template and code cleanup. If you run live integration tests or deploy to staging, AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`) will be required in the environment, but they are not strictly needed to complete the structural removal and run unit tests.

- **Acceptance criteria (checkboxes):**
  - [ ] `EstimateStorageFunction` and `EstimateTransferFunction` resources (and their log groups and Outputs) are removed from `template.yaml`, and `sam validate` passes after the changes.
  - [ ] API Gateway no longer defines or exposes `/estimate/storage` or `/estimate/transfer` routes in the SAM template.
  - [ ] The `services/estimate-storage/app.py`, `services/estimate-transfer/app.py`, and `services/estimate_transfer_entry.py` modules are no longer present or imported by any live code paths (confirmed via search and tests).
  - [ ] Tests that depended on the estimate endpoints are either removed or updated so that the test suite passes without referencing the removed Lambdas or routes.
  - [ ] `/price-storage` continues to function correctly in tests and (if deployed) in a staging stack, confirming that removing the estimate Lambdas did not break the primary quoting flow.

## Task string (optional)

Work only in the `mnemospark-backend` repo. Remove the BCM Pricing Calculator–based estimate Lambdas and their API routes from the backend by deleting the `EstimateStorageFunction` and `EstimateTransferFunction` resources and related log groups/Outputs from `template.yaml`, and by removing the corresponding modules in `services/estimate-storage`, `services/estimate-transfer`, and `services/estimate_transfer_entry.py`. Clean up all unit and integration tests that reference `/estimate/storage` and `/estimate/transfer`, ensuring that pricing coverage is provided through `/price-storage` tests instead. Run `sam validate` and the project’s tests to confirm the template and codebase are consistent and that `/price-storage` still behaves as expected. This fix depends on `fix-01-price-list-price-storage-lambda` and `fix-02-price-list-iam-and-config`.

