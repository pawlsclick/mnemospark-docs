#!/usr/bin/env python3
"""
Decode an X-Wallet-Signature header into its envelope and inner payload.

Usage:
  python3 decode_wallet_signature.py '<X-Wallet-Signature header value>'

You can paste the base64-encoded header value captured from the proxy or logs.
"""

from __future__ import annotations

import base64
import binascii
import json
import sys
from typing import Any, Dict


def _decode_base64_to_text(value: str, field_name: str) -> str:
  try:
    decoded = base64.b64decode(value, validate=True)
  except (binascii.Error, ValueError) as exc:
    raise SystemExit(f"{field_name} must be base64-encoded: {exc}") from exc
  try:
    return decoded.decode("utf-8")
  except UnicodeDecodeError as exc:
    raise SystemExit(f"{field_name} must be valid UTF-8 after base64 decode: {exc}") from exc


def _parse_json_object(raw_json: str, field_name: str) -> Dict[str, Any]:
  try:
    parsed = json.loads(raw_json)
  except json.JSONDecodeError as exc:
    raise SystemExit(f"{field_name} must contain valid JSON: {exc}") from exc
  if not isinstance(parsed, dict):
    raise SystemExit(f"{field_name} JSON must be an object")
  return parsed


def main(argv: list[str]) -> None:
  if len(argv) != 2:
    print(__doc__)
    raise SystemExit(1)

  header_value = argv[1].strip()
  if not header_value:
    raise SystemExit("Header value must be non-empty")

  print("=== Step 1: Decode outer envelope (X-Wallet-Signature) ===")
  envelope_json = _decode_base64_to_text(header_value, "X-Wallet-Signature")
  print("Raw envelope JSON:")
  print(envelope_json)
  print()

  envelope = _parse_json_object(envelope_json, "X-Wallet-Signature")

  payload_b64 = str(envelope.get("payloadB64", "")).strip()
  signature = str(envelope.get("signature", "")).strip()
  address = str(envelope.get("address", "")).strip()

  print("Envelope fields:")
  print(json.dumps({"payloadB64": payload_b64, "signature": signature, "address": address}, indent=2))
  print()

  if not payload_b64:
    raise SystemExit("payloadB64 is missing or empty in envelope")

  print("=== Step 2: Decode inner payload (MnemosparkRequest) ===")
  payload_json = _decode_base64_to_text(payload_b64, "payloadB64")
  print("Raw payload JSON:")
  print(payload_json)
  print()

  payload = _parse_json_object(payload_json, "payloadB64")
  print("Parsed payload object:")
  print(json.dumps(payload, indent=2))


if __name__ == "__main__":
  main(sys.argv)

