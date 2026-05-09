"""Verify mnemospark-lite paid upload against a live API (see scripts/README.md)."""

from __future__ import annotations

import base64
import json
import mimetypes
import os
from pathlib import Path
import time
from urllib import request as urllib_request
from urllib.error import HTTPError


def _http_json(
    method: str,
    url: str,
    *,
    body: dict | None = None,
    headers: dict[str, str] | None = None,
):
    data = None
    if body is not None:
        data = json.dumps(body, separators=(",", ":")).encode("utf-8")

    req = urllib_request.Request(url, data=data, method=method.upper())
    req.add_header("Accept", "application/json")
    if body is not None:
        req.add_header("Content-Type", "application/json")
    for k, v in (headers or {}).items():
        req.add_header(k, v)

    try:
        with urllib_request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8")
            parsed = json.loads(raw) if raw else None
            return resp.status, dict(resp.headers.items()), parsed
    except HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(raw) if raw else None
        except Exception:
            parsed = raw
        return exc.code, dict(exc.headers.items()), parsed


def _http_put_bytes(url: str, *, content_type: str, data: bytes):
    req = urllib_request.Request(url, data=data, method="PUT")
    req.add_header("Content-Type", content_type)
    with urllib_request.urlopen(req, timeout=60) as resp:
        return resp.status, dict(resp.headers.items())


def main() -> int:
    api_base = os.environ.get("MNEMOSPARK_API_BASE_URL", "").strip().rstrip("/")
    if not api_base:
        raise SystemExit("MNEMOSPARK_API_BASE_URL is required")

    wallet_key_path = Path(os.environ.get("MNEMOSPARK_WALLET_KEY_PATH", "")).expanduser()
    if not wallet_key_path.is_file():
        raise SystemExit("MNEMOSPARK_WALLET_KEY_PATH must point to an existing file")

    test_file_path = Path(os.environ.get("MNEMOSPARK_TEST_FILE", "")).expanduser()
    if not test_file_path.is_file():
        raise SystemExit("MNEMOSPARK_TEST_FILE must point to an existing file")

    tier = (os.environ.get("MNEMOSPARK_TIER") or "10mb").strip()
    content_type = (os.environ.get("MNEMOSPARK_CONTENT_TYPE") or "").strip()
    if not content_type:
        content_type = mimetypes.guess_type(str(test_file_path))[0] or "application/octet-stream"

    from eth_account import Account  # type: ignore
    from x402 import x402ClientSync  # type: ignore
    from x402.schemas import PaymentRequired, PaymentRequirements, ResourceInfo  # type: ignore
    from x402.mechanisms.evm.exact import ExactEvmScheme  # type: ignore

    raw_key = wallet_key_path.read_text(encoding="utf-8").strip()
    acct = Account.from_key(raw_key)

    upload_endpoint = f"{api_base}/api/mnemospark-lite/upload"

    size_bytes = test_file_path.stat().st_size
    filename = test_file_path.name

    # 1) Call once without payment to get PAYMENT-REQUIRED.
    status, resp_headers, _ = _http_json(
        "POST",
        upload_endpoint,
        body={"filename": filename, "contentType": content_type, "tier": tier, "size_bytes": int(size_bytes)},
    )
    if status != 402:
        raise SystemExit(f"Expected 402 for missing payment, got {status}")

    payment_required_b64 = resp_headers.get("PAYMENT-REQUIRED") or resp_headers.get("Payment-Required")
    if not payment_required_b64:
        raise SystemExit("Missing PAYMENT-REQUIRED header on 402 response")

    requirements_raw = json.loads(base64.b64decode(payment_required_b64).decode("utf-8"))
    if not isinstance(requirements_raw, dict) or "accepts" not in requirements_raw:
        raise SystemExit("Unexpected PAYMENT-REQUIRED payload shape")

    accepts: list[PaymentRequirements] = []
    for req in requirements_raw.get("accepts") or []:
        if not isinstance(req, dict):
            continue
        accepts.append(
            PaymentRequirements(
                scheme=str(req.get("scheme") or ""),
                network=str(req.get("network") or ""),
                asset=str(req.get("asset") or ""),
                amount=str(req.get("amount") or ""),
                pay_to=str(req.get("payTo") or ""),
                max_timeout_seconds=int(req.get("maxTimeoutSeconds") or 3600),
                extra=dict(req.get("extra") or {}),
            )
        )
    if not accepts:
        raise SystemExit("No payment requirements found in PAYMENT-REQUIRED")

    payment_required = PaymentRequired(
        x402_version=2,
        resource=ResourceInfo(url=upload_endpoint, mime_type="application/json", description="mnemospark-lite upload"),
        accepts=accepts,
    )

    x402_client = x402ClientSync()
    x402_client.register("eip155:*", ExactEvmScheme(acct))
    payment_payload = x402_client.create_payment_payload(payment_required)

    payment_sig_value = base64.b64encode(
        json.dumps(payment_payload.model_dump(), separators=(",", ":")).encode("utf-8")
    ).decode("ascii")

    # 2) Paid create upload slot. This may return 202 while CDP settlement is pending; retry.
    paid_resp = None
    started = time.time()
    while True:
        status, _, paid_resp = _http_json(
            "POST",
            upload_endpoint,
            body={"filename": filename, "contentType": content_type, "tier": tier, "size_bytes": int(size_bytes)},
            headers={"PAYMENT-SIGNATURE": payment_sig_value},
        )
        if status == 200 and isinstance(paid_resp, dict) and paid_resp.get("success"):
            break
        if status == 202:
            if time.time() - started > 60:
                raise SystemExit(f"Paid upload slot still pending after 60s: status={status} body={paid_resp}")
            time.sleep(2)
            continue
        raise SystemExit(f"Paid upload slot failed: status={status} body={paid_resp}")

    data = paid_resp.get("data") or {}
    upload_id = data.get("uploadId")
    presigned_put = data.get("uploadUrl")
    completion_token = data.get("completion_token")
    bearer = data.get("list_scope_bearer")
    if not (upload_id and presigned_put and completion_token and bearer):
        raise SystemExit(f"Missing required fields in paid response: keys={sorted(list(data.keys()))}")

    # 3) PUT bytes.
    file_bytes = test_file_path.read_bytes()
    put_status, _ = _http_put_bytes(presigned_put, content_type=content_type, data=file_bytes)
    if put_status not in (200, 201, 204):
        raise SystemExit(f"Presigned PUT failed with status {put_status}")

    # 4) Complete.
    complete_endpoint = f"{api_base}/api/mnemospark-lite/upload/complete"
    complete_resp = None
    started = time.time()
    while True:
        status, _, complete_resp = _http_json(
            "POST",
            complete_endpoint,
            body={"uploadId": upload_id, "completion_token": completion_token},
        )
        if status == 200 and isinstance(complete_resp, dict) and complete_resp.get("success"):
            break
        if status == 202:
            if time.time() - started > 45:
                raise SystemExit(f"Complete still pending after 45s: status={status} body={complete_resp}")
            time.sleep(2)
            continue
        raise SystemExit(f"Complete failed: status={status} body={complete_resp}")

    upload = (complete_resp.get("data") or {}).get("upload") or {}
    public_url = upload.get("publicUrl")
    if not public_url:
        raise SystemExit("Complete response missing publicUrl")

    # 5) Verify list + detail.
    list_endpoint = f"{api_base}/api/mnemospark-lite/uploads"
    status, _, list_resp = _http_json("GET", list_endpoint, headers={"Authorization": f"Bearer {bearer}"})
    if status != 200:
        raise SystemExit(f"List failed: status={status} body={list_resp}")

    detail_endpoint = f"{api_base}/api/mnemospark-lite/download/{upload_id}"
    status, _, detail_resp = _http_json("GET", detail_endpoint, headers={"Authorization": f"Bearer {bearer}"})
    if status != 200:
        raise SystemExit(f"Detail failed: status={status} body={detail_resp}")

    detail_upload = (detail_resp.get("data") or {}).get("upload") if isinstance(detail_resp, dict) else None
    download_url = detail_upload.get("downloadUrl") if isinstance(detail_upload, dict) else None

    print(json.dumps({"uploadId": upload_id, "publicUrl": public_url, "downloadUrl": download_url}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
