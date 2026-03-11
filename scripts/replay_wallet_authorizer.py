#!/usr/bin/env python3
"""
Replay a captured X-Wallet-Signature header through the wallet authorizer logic.

This uses the same verification code as the WalletAuthorizerFunction Lambda in
mnemospark-backend/services/wallet-authorizer/app.py.

Usage:
  python3 replay_wallet_authorizer.py '<X-Wallet-Signature header>' [METHOD] [PATH]

Defaults:
  METHOD = POST
  PATH   = /storage/upload
"""

from __future__ import annotations

import base64
import binascii
import os
import sys
from pathlib import Path
from typing import Any


def _add_backend_wallet_authorizer_to_path() -> None:
  """
  Ensure mnemospark-backend/services/wallet-authorizer is importable as a module named app.

  Looks for mnemospark-backend in two places:
    1. Sibling of mnemospark-docs (e.g. Projects/mnemospark-docs + Projects/mnemospark-backend)
    2. Child of mnemospark-docs (mnemospark-docs/mnemospark-backend)
  """

  docs_root = Path(__file__).resolve().parents[1]  # mnemospark-docs root
  candidates = [
    docs_root.parent / "mnemospark-backend",  # sibling
    docs_root / "mnemospark-backend",         # child
  ]
  wallet_authorizer_dir = None
  for backend_root in candidates:
    d = backend_root / "services" / "wallet-authorizer"
    if d.is_dir():
      wallet_authorizer_dir = d
      break

  if wallet_authorizer_dir is None:
    raise SystemExit(
      "Could not find wallet-authorizer directory. Looked for:\n  "
      + "\n  ".join(str(c / "services" / "wallet-authorizer") for c in candidates)
      + "\nRun this script from a workspace where mnemospark-docs and mnemospark-backend "
      "are siblings, or mnemospark-backend is inside mnemospark-docs."
    )

  sys.path.insert(0, str(wallet_authorizer_dir))


def main(argv: list[str]) -> None:
  if len(argv) < 2:
    print(__doc__)
    raise SystemExit(1)

  header_value = argv[1].strip()
  method = (argv[2] if len(argv) > 2 else "POST").strip().upper()
  path = (argv[3] if len(argv) > 3 else "/storage/upload").strip()

  if not header_value:
    raise SystemExit("Header value must be non-empty")

  _add_backend_wallet_authorizer_to_path()

  try:
    import app  # type: ignore[import-not-found]
  except Exception as exc:
    raise SystemExit(f"Failed to import wallet-authorizer app.py: {exc}") from exc

  # Optionally allow overriding env vars to match Lambda config.
  os.environ.setdefault("MNEMOSPARK_AUTH_MAX_AGE_SECONDS", "300")
  os.environ.setdefault("MNEMOSPARK_REQUEST_VERIFYING_CONTRACT", "0x0000000000000000000000000000000000000001")

  print(f"Replaying header with method={method!r}, path={path!r}")

  # First, try to parse and print the proof using the same helpers the Lambda uses.
  try:
    proof = app._parse_wallet_proof(header_value)  # type: ignore[attr-defined]
  except Exception as exc:
    print("Failed to parse wallet proof:")
    print(f"  {type(exc).__name__}: {exc}")
    raise SystemExit(1)

  print("\nParsed WalletProof (from app._parse_wallet_proof):")
  print(f"  method         = {proof.method!r}")
  print(f"  path           = {proof.path!r}")
  print(f"  wallet_address = {proof.wallet_address!r}")
  print(f"  nonce          = {proof.nonce!r}")
  print(f"  timestamp      = {proof.timestamp!r}")
  print(f"  declared_addr  = {proof.declared_address!r}")
  print(f"  signature      = {proof.signature!r}")

  # Now run full verification, which applies method/path and timestamp checks and EIP-712 recovery.
  try:
    signer = app._verify_wallet_proof(header_value, method=method, path=path)  # type: ignore[attr-defined]
  except Exception as exc:
    print("\nEIP-712 verification FAILED:")
    print(f"  {type(exc).__name__}: {exc}")
    raise SystemExit(1)

  print("\nEIP-712 verification SUCCEEDED")
  print(f"  signer address = {signer}")


if __name__ == "__main__":
  main(sys.argv)

