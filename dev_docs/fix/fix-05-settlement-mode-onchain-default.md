# Cursor Dev: Default Payment Settlement Mode to Onchain

**ID:** fix-05  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. This repo is a serverless AWS Lambda backend (Python 3.13) using AWS SAM. The storage upload Lambda lives at `services/storage-upload/app.py`. Do **not** clone, or require access to any other repository; all code and references are in this file References.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Change the **payment settlement mode default from `mock` to `onchain`**. Currently `MNEMOSPARK_PAYMENT_SETTLEMENT_MODE` defaults to `mock` in both `app.py` (line 870) and `template.yaml` (line 39). In mock mode, no actual USDC transfer occurs. The production default must be `onchain` so that real payments are collected. An explicit environment variable override is required to switch to `mock` (for testing/development only).

**Changes required:**

1. **Update `template.yaml`** -- change the `PaymentSettlementMode` parameter default:

   Current (`template.yaml` lines 37-43):
   ```yaml
   PaymentSettlementMode:
     Type: String
     Default: mock
     AllowedValues:
       - mock
       - onchain
     Description: Payment settlement mode for upload flow
   ```

   Change to:
   ```yaml
   PaymentSettlementMode:
     Type: String
     Default: onchain
     AllowedValues:
       - mock
       - onchain
     Description: >-
       Payment settlement mode for upload flow. Default is onchain (real USDC
       transfers on Base). Set to mock only for testing/development (generates
       deterministic pseudo-tx IDs, no on-chain transaction).
   ```

2. **Update `services/storage-upload/app.py`** -- change the default in `verify_and_settle_payment()`:

   Current (line 870):
   ```python
   settlement_mode = os.environ.get("MNEMOSPARK_PAYMENT_SETTLEMENT_MODE", "mock").strip().lower() or "mock"
   ```

   Change to:
   ```python
   settlement_mode = os.environ.get("MNEMOSPARK_PAYMENT_SETTLEMENT_MODE", "onchain").strip().lower() or "onchain"
   ```

3. **Add a startup log warning** when running in mock mode. At the top of `lambda_handler()` (or as a module-level cold-start check), log a WARNING when mock mode is active:

   ```python
   if settlement_mode == "mock":
       logger.warning(json.dumps({
           "event": "mock_settlement_mode_active",
           "message": "Payment settlement is in MOCK mode. No real USDC transfers will occur. Set MNEMOSPARK_PAYMENT_SETTLEMENT_MODE=onchain for production.",
       }))
   ```

   This assumes fix-03 (logging) has already been applied. If the logger is not yet available, use `print()` as a fallback.

4. **Update existing unit tests** that rely on the mock default. Tests that do not set `MNEMOSPARK_PAYMENT_SETTLEMENT_MODE` will now default to `onchain`. For tests that need mock behavior, explicitly set the environment variable:
   ```python
   @mock.patch.dict(os.environ, {"MNEMOSPARK_PAYMENT_SETTLEMENT_MODE": "mock"})
   def test_something_with_mock_settlement(self):
       ...
   ```

   Search all test files for tests that depend on mock settlement and add the explicit env override.

## References

- `services/storage-upload/app.py` -- `verify_and_settle_payment()` (line 791), settlement mode line (line 870), `_mock_settlement_tx_id()`, `_onchain_settle_payment()`
- `template.yaml` -- `PaymentSettlementMode` parameter (lines 37-43), `StorageUploadFunction` environment variables (line 554)
- `tests/unit/test_storage_upload.py` -- existing unit tests that may rely on mock default
- `tests/integration/test_storage_upload_integration.py` -- integration tests
- [cloud-upload-process-flow.md](../../meta_docs/cloud-upload-process-flow.md) section 8.5

## Agent

- **Install (idempotent):** `source /workspace/.venv/bin/activate && pip install -r services/storage-upload/requirements.txt`
- **Start (if needed):** None.
- **Secrets:** None required for unit tests (mocked).
- **Acceptance criteria (checkboxes):**
  - [ ] `template.yaml` `PaymentSettlementMode` parameter default is `onchain`
  - [ ] `app.py` line 870 default is `"onchain"` (not `"mock"`)
  - [ ] A WARNING-level log is emitted when mock mode is active
  - [ ] Existing unit tests that need mock mode explicitly set `MNEMOSPARK_PAYMENT_SETTLEMENT_MODE=mock` via `@mock.patch.dict(os.environ, ...)`
  - [ ] Lint passes: `ruff check services/storage-upload/`
  - [ ] Tests pass: `pytest tests/ -v`
  - [ ] The agent creates a new branch, commits, and opens a PR

## Task string (optional)

Work only in this repo (mnemospark-backend). Change the payment settlement mode default from `mock` to `onchain`. In `template.yaml`, change `PaymentSettlementMode` Default from `mock` to `onchain` and update the description. In `services/storage-upload/app.py` line 870, change the `os.environ.get()` default from `"mock"` to `"onchain"`. Add a WARNING log when mock mode is active. Update any unit tests that relied on the mock default to explicitly set `MNEMOSPARK_PAYMENT_SETTLEMENT_MODE=mock`. Run `ruff check services/storage-upload/` and `pytest tests/ -v`. Create a new branch and PR.
