"""Publish a verified DMG through the locally configured MeeTar COS uploader."""

import argparse
import hashlib
import importlib.util
import json
import sys
import urllib.request
from pathlib import Path

from medict_distribution import OUTPUT, ROOT, sha256, write_json


def command():
    """Resolve local tool paths without copying COS credentials into this repository."""
    path = ROOT / "ME-Dict.publish.local.json"
    if not path.is_file():
        raise RuntimeError("Create ME-Dict.publish.local.json; see the distribution guide.")
    settings = json.loads(path.read_text())
    keys = ("python", "uploader", "config")
    if not isinstance(settings, dict) or set(settings) != set(keys):
        raise RuntimeError("Publish settings require only python, uploader and config paths.")
    paths = []
    for key in keys:
        if not isinstance(settings[key], str) or not settings[key].strip():
            raise RuntimeError(f"Invalid publish {key} path.")
        # Preserve a virtualenv interpreter symlink; resolving it loses the environment.
        value = (ROOT / Path(settings[key]).expanduser()).absolute()
        if not value.is_file():
            raise RuntimeError(f"Publish {key} file is missing: {value}")
        paths.append(str(value))
    return [paths[0], str(ROOT / "scripts/medict_cos.py"),
            "--uploader", paths[1], "--config", paths[2]]


def verify_download(url, expected_size, expected_sha):
    """Read every public byte without credentials before reporting a download link."""
    request = urllib.request.Request(url, headers={"User-Agent": "curl/8.1.2"})
    digest = hashlib.sha256()
    size = 0
    with urllib.request.urlopen(request, timeout=60) as response:
        if response.status != 200 or response.url != url:
            raise RuntimeError("Public download returned an unexpected status or redirect.")
        content_type = response.headers.get("Content-Type", "").split(";")[0]
        if content_type not in {"application/x-apple-diskimage", "application/octet-stream"}:
            raise RuntimeError("Public download did not return a disk image.")
        while chunk := response.read(1024 * 1024):
            digest.update(chunk)
            size += len(chunk)
            if size > expected_size:
                raise RuntimeError("Public download is larger than the signed DMG.")
    if size != expected_size or digest.hexdigest() != expected_sha:
        raise RuntimeError("Public download differs from the signed DMG.")
    return {"http_status": 200, "content_type": content_type,
            "size_bytes": size, "sha256": digest.hexdigest()}


def publish(uploader, config, client, directory):
    state = json.loads((directory / "state.json").read_text())
    if state["status"] != "ready":
        raise RuntimeError("Only a ready, notarized DMG can be uploaded.")
    artifact = directory / "artifacts" / state["dmg"]
    if sha256(artifact) != state["sha256"]:
        raise RuntimeError("DMG changed before upload.")
    prefix = f'medict/releases/{state["version"]}-{state["build"]}/{state["sha256"]}'
    options = {"bucket": "file", "prefix": prefix, "keep_name": True}
    plan = uploader.upload_asset(artifact, config, dry_run=True, **options)
    if plan["status"] != "planned":
        raise RuntimeError("COS upload plan failed.")
    write_json(directory / "cos-plan.json", plan)

    from qcloud_cos.cos_exception import CosServiceError

    exists = False
    try:
        metadata = client.head_object(Bucket=plan["bucket"], Key=plan["key"])
        exists = True
        if (int(metadata["Content-Length"]) != plan["size_bytes"]
                or metadata.get("ETag", "").strip('"') != plan["md5"]):
            raise RuntimeError("A different COS object already exists; refusing to overwrite it.")
    except CosServiceError as error:
        if error.get_status_code() != 404 or error.get_error_code() not in {"NoSuchKey", "NoSuchResource"}:
            raise RuntimeError(f"COS lookup failed: {error.get_error_code()}") from None
    if not exists:
        result = uploader.upload_asset(artifact, config, **options)
        write_json(directory / "cos-upload.json", result)
        if result["status"] != "success":
            raise RuntimeError("COS upload failed; inspect cos-upload.json and resume this run.")
    verification = verify_download(plan["url"], plan["size_bytes"], state["sha256"])
    receipt = {"status": "verified", "bucket": plan["bucket"], "key": plan["key"],
               "url": plan["url"], "reused": exists, **verification}
    write_json(directory / "artifacts/publication.json", receipt)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--uploader", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("action", choices=("check", "upload"))
    parser.add_argument("run_id", nargs="?")
    args = parser.parse_args()
    # Use the existing skill's configuration, routing and upload implementation unchanged.
    sys.path.insert(0, str(args.uploader.parent))
    spec = importlib.util.spec_from_file_location("medict_cos_uploader", args.uploader)
    uploader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(uploader)
    config = uploader.merge_runtime_config(str(args.config))
    client = uploader.get_cos_client(config)
    if args.action == "check":
        client.head_bucket(Bucket=uploader.BUCKET_MAP["file"]["bucket"])
        print("COS configuration and bucket access verified.")
        return
    import re

    if not args.run_id or not re.fullmatch(r"[0-9TZ-]+-[a-f0-9]{8}", args.run_id):
        raise RuntimeError("Invalid publication run ID.")
    directory = OUTPUT / args.run_id
    if directory.is_symlink():
        raise RuntimeError("Run directory must not be a symlink.")
    publish(uploader, config, client, directory)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # SDK errors may contain signed request details; do not echo them to the terminal.
        detail = str(error) if isinstance(error, RuntimeError) else type(error).__name__
        print(f"COS publication stopped: {detail}", file=sys.stderr)
        sys.exit(1)
