# Cursor Dev: Add Presigned URL Upload Path to Backend

**ID:** fix-02  
**Repo:** mnemospark-backend

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-backend. This repo is a serverless AWS Lambda backend (Python 3.13) using AWS SAM. The storage upload Lambda lives at `services/storage-upload/app.py`. Do **not** clone, or require access to any other repository; all code and references are in this file References.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Add a **presigned URL upload path** to the `/storage/upload` Lambda handler so that files larger than ~4.5 MB can be uploaded. Depends on fix-01 (the client now sends `mode` at the top level after payload flattening).

Currently the handler always expects `ciphertext` in the request body and writes directly via `s3:PutObject`. The client sends `mode: "presigned"` for large files and expects the backend response to include an `upload_url` (S3 presigned PUT URL). Without this, large-file uploads fail.

**Changes required:**

1. **Update `ParsedUploadRequest` dataclass** (`app.py` line 132) to add optional fields:
   - `mode: str | None` (values: `"inline"`, `"presigned"`, or `None` for backwards compatibility)
   - `content_sha256: str | None`
   - `content_length_bytes: int | None`
   - Make `ciphertext` optional: `ciphertext: bytes | None` (instead of `bytes`)

2. **Update `parse_input()`** (`app.py` line 399) to:
   - Read `mode` from `params.get("mode")`. Default to `"inline"` if absent.
   - When `mode == "presigned"`, do NOT require `ciphertext` -- allow it to be `None`.
   - Read `content_sha256` and `content_length_bytes` if present.
   - When `mode == "inline"`, keep existing behavior (require `ciphertext`).

3. **Update API Gateway model** (`template.yaml` lines 374-401):
   - Remove `ciphertext` from the `required` list (it is optional when `mode` is `"presigned"`).
   - Add `mode`, `content_sha256`, and `content_length_bytes` to `properties`.

4. **Update `lambda_handler()`** (`app.py` line 1086) to branch on `mode`:
   - **Inline path** (existing, `mode == "inline"` or `mode is None`): keep current behavior -- `_upload_ciphertext_to_s3()`, write transaction log, return 200.
   - **Presigned path** (`mode == "presigned"`):
     a. After payment verification, generate a presigned S3 PUT URL:
        ```python
        s3_client = boto3.client("s3", region_name=quote_context.location)
        bucket_name = _bucket_name(request.wallet_address)
        _validate_bucket_name(bucket_name)
        _ensure_bucket_exists(s3_client, bucket_name, quote_context.location)
        upload_url = s3_client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": bucket_name,
                "Key": request.object_key,
                "Metadata": {"wrapped-dek": request.wrapped_dek},
            },
            ExpiresIn=3600,
        )
        ```
     b. Write the transaction log (payment is already settled).
     c. Delete the consumed quote (best-effort).
     d. Return 200 with the presigned URL in the response body:
        ```json
        {
          "quote_id": "...",
          "addr": "...",
          "addr_hash": "...",
          "trans_id": "...",
          "storage_price": 1.25,
          "object_id": "...",
          "object_key": "...",
          "provider": "aws",
          "bucket_name": "mnemospark-...",
          "location": "us-east-1",
          "upload_url": "https://mnemospark-....s3.amazonaws.com/...?X-Amz-...",
          "upload_headers": {"content-type": "application/octet-stream"}
        }
        ```

5. **Update `_request_fingerprint()`** (`app.py` line 886): when `mode == "presigned"` and `ciphertext` is `None`, use `content_sha256` instead of `hashlib.sha256(request.ciphertext).hexdigest()` for the fingerprint. Fall back gracefully.

6. **Add unit tests** in `tests/unit/test_storage_upload.py` for the presigned path:
   - A request with `mode: "presigned"` and no `ciphertext` returns 200 with `upload_url`.
   - A request with `mode: "inline"` and `ciphertext` uses the existing direct-upload path.
   - A request with `mode: "presigned"` still requires payment verification.

## References

- `services/storage-upload/app.py` -- `ParsedUploadRequest` dataclass (line 132), `parse_input()` (line 399), `_upload_ciphertext_to_s3()` (line 1025), `lambda_handler()` (line 1086), `_request_fingerprint()` (line 886), `_bucket_name()`, `_validate_bucket_name()`, `_ensure_bucket_exists()` (lines 359-396)
- `template.yaml` -- `StorageUploadRequest` API Gateway model (lines 374-401), `StorageUploadFunction` resource (lines 540-584)
- `tests/unit/test_storage_upload.py` -- existing unit tests with mocked DynamoDB and S3
- Client `StorageUploadResponse` type (for reference only): `{ quote_id, addr, addr_hash, trans_id, storage_price, object_id, object_key, provider, bucket_name, location, upload_url?, upload_headers? }`
- Client presigned upload handler (for reference only): `uploadPresignedObjectIfNeeded()` in `mnemospark/src/cloud-command.ts` line 1016 -- PUTs encrypted content to `upload_url` with `upload_headers`

## Agent

- **Install (idempotent):** `source /workspace/.venv/bin/activate && pip install -r services/storage-upload/requirements.txt`
- **Start (if needed):** None.
- **Secrets:** None required for unit tests (mocked).
- **Acceptance criteria (checkboxes):**
  - [ ] `ParsedUploadRequest` has new optional fields: `mode`, `content_sha256`, `content_length_bytes`; `ciphertext` is now `bytes | None`
  - [ ] `parse_input()` reads `mode` from params; when `mode == "presigned"`, `ciphertext` is not required
  - [ ] API Gateway model in `template.yaml` no longer requires `ciphertext` and includes `mode` property
  - [ ] `lambda_handler()` branches: inline mode calls `_upload_ciphertext_to_s3()`; presigned mode generates a presigned S3 PUT URL
  - [ ] Presigned path response includes `upload_url` and `upload_headers` keys
  - [ ] `_request_fingerprint()` handles `ciphertext is None` gracefully using `content_sha256`
  - [ ] Unit tests cover both inline and presigned paths
  - [ ] Lint passes: `ruff check services/storage-upload/`
  - [ ] Tests pass: `pytest tests/ -v`
  - [ ] The agent creates a new branch, commits, and opens a PR

## Task string (optional)

Work only in this repo (mnemospark-backend). In `services/storage-upload/app.py`, add a presigned URL upload path. Make `ciphertext` optional in `ParsedUploadRequest` and `parse_input()`. When `mode == "presigned"`, generate a presigned S3 PUT URL via `s3_client.generate_presigned_url()` and return it as `upload_url` in the response. Update the API Gateway model in `template.yaml` to not require `ciphertext`. Update `_request_fingerprint()` to handle `ciphertext is None`. Add unit tests for both inline and presigned paths. Run `ruff check services/storage-upload/` and `pytest tests/ -v`. Create a new branch and PR.
