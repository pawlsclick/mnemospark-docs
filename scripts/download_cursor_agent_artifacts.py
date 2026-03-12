#!/usr/bin/env python3
"""
Download artifacts from a Cursor Cloud Agent.

Usage (from any directory):

    export CURSOR_API_KEY=your_api_key_here
    python /path/to/mnemospark-docs/scripts/download_cursor_agent_artifacts.py \
        --agent-id bc_abc123 \
        /opt/cursor/artifacts/mnemospark_two_commits_82f3176_d93b5ef.patch \
        /opt/cursor/artifacts/mnemospark_two_commits_series/0001-Add-presigned-upload-confirmation-flow.patch \
        /opt/cursor/artifacts/mnemospark_two_commits_series/0002-Improve-cloud-command-messaging-and-proxy-diagnostic.patch \
        /opt/cursor/artifacts/mnemospark_docs_ee503d9.patch \
        /opt/cursor/artifacts/pr_apply_steps.txt

Files are saved into the present working directory using the basename
of each artifact path.
"""

import argparse
import os
import sys
from pathlib import Path

import requests


API_BASE = "https://api.cursor.com"
ENV_API_KEY = "CURSOR_API_KEY"


def get_api_key() -> str:
    api_key = os.getenv(ENV_API_KEY)
    if not api_key:
        raise SystemExit(
            f"{ENV_API_KEY} environment variable is not set. "
            f"Export your Cursor API key, e.g.:\n\n"
            f"    export {ENV_API_KEY}=your_api_key_here\n"
        )
    return api_key


def build_download_url(agent_id: str, artifact_path: str) -> str:
    return f"{API_BASE}/v0/agents/{agent_id}/artifacts/download"


def fetch_presigned_url(api_key: str, agent_id: str, artifact_path: str) -> str:
    url = build_download_url(agent_id, artifact_path)
    params = {"path": artifact_path}

    resp = requests.get(url, params=params, auth=(api_key, ""))
    if resp.status_code != 200:
        raise SystemExit(
            f"Failed to get presigned URL for '{artifact_path}' "
            f"(agent {agent_id}): HTTP {resp.status_code} {resp.text}"
        )

    data = resp.json()
    presigned = data.get("url")
    if not presigned:
        raise SystemExit(
            f"No 'url' field in response when requesting presigned URL "
            f"for '{artifact_path}'. Response was: {data!r}"
        )
    return presigned


def download_artifact(presigned_url: str, output_path: Path) -> None:
    with requests.get(presigned_url, stream=True) as resp:
        resp.raise_for_status()
        with output_path.open("wb") as f:
            for chunk in resp.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)


def parse_args(argv):
    parser = argparse.ArgumentParser(
        description="Download artifacts from a Cursor Cloud Agent "
        "into the current working directory."
    )
    parser.add_argument(
        "--agent-id",
        required=True,
        help="ID of the Cursor Cloud Agent (e.g. bc_abc123).",
    )
    parser.add_argument(
        "artifact_paths",
        nargs="+",
        help=(
            "One or more artifact absolute paths, as returned by the "
            "/v0/agents/{id}/artifacts endpoint "
            "(e.g. /opt/cursor/artifacts/foo.patch)."
        ),
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv or sys.argv[1:])
    api_key = get_api_key()

    agent_id = args.agent_id
    artifact_paths = args.artifact_paths

    for artifact_path in artifact_paths:
        basename = os.path.basename(artifact_path.rstrip("/"))
        if not basename:
            print(f"Skipping empty basename for path '{artifact_path}'", file=sys.stderr)
            continue

        output_path = Path.cwd() / basename
        print(f"Downloading '{artifact_path}' to '{output_path}'...")

        presigned_url = fetch_presigned_url(api_key, agent_id, artifact_path)
        download_artifact(presigned_url, output_path)

        print(f"  -> Saved to {output_path}")


if __name__ == "__main__":
    main()

