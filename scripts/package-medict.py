#!/usr/bin/env python3
"""Build, notarize and package ME-Dict without modifying installed applications."""

import argparse
from datetime import datetime, timezone
import fcntl
import json
import re
import subprocess
import sys
import uuid

from medict_distribution import (OUTPUT, ROOT, build, create_dmg, load_config, preflight,
                                 run, sha256, signature, verify_app, verify_certificate, write_json)
from medict_cos import command as cos_command


def publish_ready(directory, state, config):
    """Verify the finalized artifact, then upload or reuse it and print only a verified URL."""
    expected = f'ME-Dict-{state["version"]}-{state["build"]}-arm64.dmg'
    if state["status"] != "ready" or state["dmg"] != expected:
        raise RuntimeError("Publication requires a completed DMG.")
    if any(state["notarization"][label]["status"] != "Accepted" for label in ("app", "dmg")):
        raise RuntimeError("App and DMG notarization must both be Accepted.")
    final = directory / "artifacts" / expected
    if sha256(final) != state["sha256"]:
        raise RuntimeError("Completed DMG checksum changed.")
    signature(final, config)
    verify_certificate(final, config["certificate_sha1"])
    run(["xcrun", "stapler", "validate", str(final)], directory / "publish-ticket.log")
    run(["spctl", "--assess", "--type", "open", "--context", "context:primary-signature",
         "--verbose=4", str(final)], directory / "publish-gatekeeper.log")
    state["publish"] = True
    write_json(directory / "state.json", state)
    run(cos_command() + ["upload", directory.name], directory / "cos-publish.log")
    receipt = json.loads((directory / "artifacts/publication.json").read_text())
    if receipt["status"] != "verified" or receipt["sha256"] != state["sha256"]:
        raise RuntimeError("COS publication was not verified.")
    state["publication"] = receipt
    write_json(directory / "state.json", state)
    write_json(directory / "artifacts/manifest.json", state)
    print(f'DOWNLOAD_URL: {receipt["url"]}', flush=True)


def notarize(directory, state, label, archive, config, recovered_id=None):
    """Persist upload intent and submission ID; resume polling instead of uploading again."""
    state_path = directory / "state.json"
    entries = state.setdefault("notarization", {})
    entry = entries.get(label)
    if entry is None:
        entry = {"sha256": sha256(archive), "submission_started": True}
        entries[label] = entry
        write_json(state_path, state)
        command = ["xcrun", "notarytool", "submit", str(archive), "--keychain-profile",
                   config["notary_profile"], "--output-format", "json"]
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
        (directory / f"{label}-submit.json").write_text(result.stdout)
        (directory / f"{label}-submit.log").write_text(result.stderr)
        try:
            submission = json.loads(result.stdout)
            entry["id"] = str(uuid.UUID(submission["id"]))
        except (ValueError, KeyError):
            raise RuntimeError(
                f"Upload outcome unknown; inspect {label}-submit.log and notarytool history. "
                "Resume with --submission-id if Apple received this file; do not blindly upload again."
            )
        write_json(state_path, state)
    if entry["sha256"] != sha256(archive):
        raise RuntimeError(f"{label} changed after submission; refusing to reuse its notarization.")
    if "id" not in entry:
        if not recovered_id:
            raise RuntimeError("Missing submission ID; use notarytool history and resume --submission-id ID.")
        entry["id"] = str(uuid.UUID(recovered_id))
        write_json(state_path, state)
    prefix = ["xcrun", "notarytool"]
    credentials = ["--keychain-profile", config["notary_profile"], "--output-format", "json"]
    info = json.loads(run(prefix + ["info", entry["id"]] + credentials))
    if info["status"] == "In Progress":
        print(f"Waiting for {label} notarization: {entry['id']}", flush=True)
        with (directory / f"{label}-wait.log").open("w") as stream:
            subprocess.run(prefix + ["wait", entry["id"], "--timeout", "10m"] + credentials,
                           cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        info = json.loads(run(prefix + ["info", entry["id"]] + credentials))
    entry["status"] = info["status"]
    write_json(directory / f"{label}-info.json", info)
    write_json(state_path, state)
    if info["status"] != "Accepted":
        if info["status"] != "In Progress":
            run(prefix + ["log", entry["id"], str(directory / f"{label}-issues.json")]
                + ["--keychain-profile", config["notary_profile"]])
        raise RuntimeError(f"{label} notarization: {info['status']}; no distributable artifact produced.")


def require_source(state):
    if run(["git", "rev-parse", "HEAD"]).strip() != state["commit"] or run(
        ["git", "status", "--porcelain"]
    ).strip():
        raise RuntimeError("Checkout changed during packaging; return to the recorded clean commit to resume.")


def finish(directory, state, config, recovered_id=None):
    require_source(state)
    app = directory / "export/ME-Dict.app"
    if verify_app(app, state["version"], state["build"], config) != state["app"]:
        raise RuntimeError("Application changed after the original build.")
    app_zip = directory / "notary-app.zip"
    if not app_zip.exists():
        if "app" in state.get("notarization", {}):
            raise RuntimeError("Submitted app archive is missing.")
        run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(app_zip)])
    notarize(directory, state, "app", app_zip, config, recovered_id)
    run(["xcrun", "stapler", "staple", str(app)], directory / "app-staple.log")
    run(["xcrun", "stapler", "validate", str(app)], directory / "app-ticket.log")
    run(["spctl", "--assess", "--type", "execute", "--verbose=4", str(app)], directory / "app-gatekeeper.log")
    filename = f'ME-Dict-{state["version"]}-{state["build"]}-arm64.dmg'
    dmg = directory / filename
    if not dmg.exists():
        if "dmg" in state.get("notarization", {}):
            raise RuntimeError("Submitted DMG is missing.")
        if (directory / "dmg-root").exists():
            raise RuntimeError("Incomplete DMG staging; inspect this run and start a new release.")
        require_source(state)
        dmg = create_dmg(directory, app, filename, state["commit"])
        run(["codesign", "--force", "--sign", config["certificate_sha1"], "--timestamp", str(dmg)])
    signature(dmg, config)
    verify_certificate(dmg, config["certificate_sha1"])
    # A previous stapling attempt changes the DMG's bytes; notarization input is kept separately.
    notarize(directory, state, "dmg", dmg, config, recovered_id)
    delivery = directory / "stapled"
    delivery.mkdir(exist_ok=True)
    final = delivery / filename
    run(["ditto", str(dmg), str(final)])
    run(["xcrun", "stapler", "staple", str(final)], directory / "dmg-staple.log")
    run(["xcrun", "stapler", "validate", str(final)], directory / "dmg-ticket.log")
    signature(final, config)
    run(["hdiutil", "verify", str(final)], directory / "final-dmg-verify.log")
    run(["spctl", "--assess", "--type", "open", "--context", "context:primary-signature",
         "--verbose=4", str(final)], directory / "dmg-gatekeeper.log")
    checksum = sha256(final)
    artifacts = directory / "artifacts"
    artifacts.mkdir(exist_ok=True)
    run(["ditto", str(final), str(artifacts / filename)])
    if sha256(artifacts / filename) != checksum:
        raise RuntimeError("Final DMG copy differs from verified file.")
    (artifacts / "SHA256SUMS.txt").write_text(f"{checksum}  {filename}\n")
    state.update({"status": "ready", "dmg": filename, "sha256": checksum})
    write_json(directory / "state.json", state)
    write_json(artifacts / "manifest.json", state)
    print(f"READY: {artifacts / filename}\nSHA256: {checksum}")


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("check", help="Validate the signing identity and Keychain notarization profile.")
    commands.add_parser("check-publish", help="Check signing, notarization and COS access without uploading.")
    for name in ("build-check", "release", "publish"):
        description = {"build-check": "Unsigned build validation only.",
                       "release": "Build, sign, notarize and create a distributable DMG.",
                       "publish": "Build, sign, notarize and publish a verified COS download link."}
        sub = commands.add_parser(name, help=description[name])
        sub.add_argument("--version", required=True)
        sub.add_argument("--build", required=True)
    resume = commands.add_parser("resume", help="Resume notarization using the original binaries and submission IDs.")
    resume.add_argument("run_id", help="Run directory name printed by release, not an arbitrary path.")
    resume.add_argument("--submission-id", help="Recover an upload ID after an interrupted submit response.")
    upload = commands.add_parser("upload", help="Publish an existing ready DMG without rebuilding.")
    upload.add_argument("run_id")
    args = parser.parse_args()
    if args.command in {"build-check", "release", "publish"}:
        if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
            parser.error("--version must have three numeric components, for example 2.24.0.")
        if not re.fullmatch(r"[1-9]\d*", args.build):
            parser.error("--build must be a positive integer.")
    return args


def main():
    args = parse_args()
    config = None if args.command == "build-check" else load_config()
    if config and args.command != "upload":
        preflight(config)
    if args.command in {"publish", "check-publish", "upload"}:
        run(cos_command() + ["check"])
    if args.command in {"check", "check-publish"}:
        print("Developer ID identity and notarization profile are available.")
        return
    OUTPUT.mkdir(parents=True, exist_ok=True)
    # The shared distribution DerivedData must never be used by concurrent packaging processes.
    with (OUTPUT / ".lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("Another ME-Dict distribution build is running.")
        if args.command in {"resume", "upload"}:
            if not re.fullmatch(r"[0-9TZ-]+-[a-f0-9]{8}", args.run_id):
                raise RuntimeError("Invalid run ID.")
            directory = OUTPUT / args.run_id
            if directory.is_symlink():
                raise RuntimeError("Run directory must not be a symlink.")
            state = json.loads((directory / "state.json").read_text())
            if state["status"] == "build-check":
                raise RuntimeError("Unsigned build checks cannot be promoted to a release.")
            if state["config"] != config:
                raise RuntimeError("Signing/profile configuration changed; use the original configuration to resume.")
            if state["status"] == "ready":
                if args.command == "upload" or state.get("publish"):
                    publish_ready(directory, state, config)
                    return
                final = directory / "artifacts" / state["dmg"]
                if sha256(final) != state["sha256"]:
                    raise RuntimeError("Completed DMG checksum changed.")
                run(["xcrun", "stapler", "validate", str(final)])
                print(f"Already ready: {final}")
                return
            if args.command == "upload":
                raise RuntimeError("DMG is not ready; resume packaging first.")
            finish(directory, state, config, args.submission_id)
            if state.get("publish"):
                publish_ready(directory, state, config)
            return
        if config and run(["git", "status", "--porcelain"]).strip():
            raise RuntimeError("Release requires a clean committed checkout; build-check accepts local changes.")
        run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
        directory = OUTPUT / run_id
        directory.mkdir()
        state = {"status": "building" if config else "build-check", "version": args.version,
                 "build": args.build, "commit": run(["git", "rev-parse", "HEAD"]).strip(), "config": config,
                 "publish": args.command == "publish"}
        write_json(directory / "state.json", state)
        print(f"Run: {run_id}\nLogs: {directory}", flush=True)
        app = build(directory, args.version, args.build, config)
        state["app"] = verify_app(app, args.version, args.build, config)
        state["status"] = "built" if config else "build-check"
        write_json(directory / "state.json", state)
        if not config:
            print(f"Unsigned build check passed: {app}\nNOT FOR DISTRIBUTION; installed apps were not touched.")
            return
        finish(directory, state, config)
        if state["publish"]:
            publish_ready(directory, state, config)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"ME-Dict packaging stopped: {error}", file=sys.stderr)
        sys.exit(1)
