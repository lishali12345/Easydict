#!/usr/bin/env python3
"""Build and install ME-Dict with a persistent local signing identity."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid


ROOT = Path(__file__).resolve().parent.parent
TARGET = Path("/Applications/ME-Dict.app")
OFFICIAL = Path("/Applications/Easydict.app")
LSREGISTER = (
    "/System/Library/Frameworks/CoreServices.framework/Frameworks/"
    "LaunchServices.framework/Support/lsregister"
)


def run(command, capture=True):
    result = subprocess.run(
        command, cwd=ROOT, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )
    if result.returncode:
        raise RuntimeError(
            f"{command[0]} failed ({result.returncode})"
            + (f":\n{result.stdout.strip()}" if capture else "")
        )
    return result.stdout or ""


def signing_config():
    path = ROOT / "ME-Dict.local.xcconfig"
    if not path.is_file():
        raise RuntimeError(f"Missing local signing configuration: {path}")
    values = {}
    for line in path.read_text().splitlines():
        match = re.fullmatch(
            r"\s*(DEVELOPMENT_TEAM|CODE_SIGN_IDENTITY|CODE_SIGN_STYLE)"
            r"\s*=\s*(.*?)\s*(?://.*)?", line
        )
        if match:
            key, value = match.groups()
            if key in values:
                raise RuntimeError(f"Duplicate signing setting: {key}")
            values[key] = value.strip().strip('"')
    team = values.get("DEVELOPMENT_TEAM", "")
    identity = values.get("CODE_SIGN_IDENTITY", "").upper()
    if not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise RuntimeError("DEVELOPMENT_TEAM must be a 10-character Team ID.")
    if not re.fullmatch(r"[A-F0-9]{40}", identity):
        raise RuntimeError("CODE_SIGN_IDENTITY must be a fixed certificate SHA-1 fingerprint.")
    if values.get("CODE_SIGN_STYLE") != "Manual":
        raise RuntimeError("CODE_SIGN_STYLE must be Manual.")
    identities = run(["security", "find-identity", "-v", "-p", "codesigning"])
    valid = re.findall(r'^\s*\d+\)\s+([A-Fa-f0-9]{40})\s+"', identities, re.MULTILINE)
    if identity not in (value.upper() for value in valid):
        raise RuntimeError("The configured signing identity is not valid or has no private key.")
    return team, identity


def derived_data():
    try:
        checkout = str(ROOT.relative_to(Path.home()))
    except ValueError:
        checkout = str(ROOT).lstrip("/")
    checkout = checkout.lstrip(".").replace("/", "_")
    return Path.home() / "Library/Developer/Xcode/DerivedData/Easydict-Agent" / checkout


def verify_bundle(path):
    if path.is_symlink() or not path.is_dir():
        raise RuntimeError(f"Expected an application directory, not a symlink: {path}")
    with (path / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    required = {
        "CFBundleIdentifier": "com.helihua.medict",
        "CFBundleName": "ME-Dict",
        "CFBundleDisplayName": "ME-Dict",
        "CFBundleExecutable": "ME-Dict",
        "SUEnableAutomaticChecks": False,
        "SUAutomaticallyUpdate": False,
    }
    for key, value in required.items():
        if info.get(key) != value or type(info.get(key)) is not type(value):
            raise RuntimeError(f"{path.name}: unexpected {key}")
    if "SUFeedURL" in info:
        raise RuntimeError(f"{path.name}: automatic update feed must be absent.")
    run(["codesign", "--verify", "--deep", "--strict", "--all-architectures", str(path)])
    details = run(["codesign", "-d", "--verbose=4", str(path)])
    requirement = run(["codesign", "-d", "-r-", str(path)])
    match = re.search(r"^(?:# )?designated => (.+)$", requirement, re.MULTILINE)
    if not match:
        raise RuntimeError(f"Missing designated requirement: {path}")
    team = re.search(r"^TeamIdentifier=(.+)$", details, re.MULTILINE)
    return {
        "adhoc": "Signature=adhoc" in details,
        "team": team.group(1) if team else None,
        "requirement": match.group(1),
    }


def verify_signed_bundle(path, team, identity):
    signature = verify_bundle(path)
    if signature["adhoc"] or signature["team"] != team:
        raise RuntimeError(f"{path.name}: expected certificate signing with Team {team}.")
    with tempfile.TemporaryDirectory(prefix="medict-public-certificate-") as directory:
        prefix = Path(directory) / "certificate"
        run(["codesign", "-d", f"--extract-certificates={prefix}", str(path)])
        fingerprint = hashlib.sha1(Path(f"{prefix}0").read_bytes()).hexdigest().upper()
    if fingerprint != identity:
        raise RuntimeError(f"{path.name}: signing certificate differs from the local configuration.")
    return signature


def file_hashes(path):
    if not path.exists():
        return None
    result = {}
    if path.is_symlink():
        result["."] = "symlink:" + os.readlink(path)
    for item in sorted(path.rglob("*")):
        key = str(item.relative_to(path))
        if item.is_symlink():
            result[key] = "symlink:" + os.readlink(item)
        elif item.is_file():
            digest = hashlib.sha256()
            with item.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
            result[key] = digest.hexdigest()
    return result


def hash_summary(files):
    if files is None:
        return None
    return {
        "entries": len(files),
        "sha256": hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest(),
    }


def stop_installed_app():
    executable = str(TARGET / "Contents/MacOS/ME-Dict")
    processes = run(["ps", "-axo", "pid=,args="])
    pending = []
    for line in processes.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) == 2 and (
            fields[1] == executable or fields[1].startswith(executable + " ")
        ):
            pid = int(fields[0])
            try:
                os.kill(pid, signal.SIGTERM)
                pending.append(pid)
            except ProcessLookupError:
                pass
    was_running = bool(pending)
    deadline = time.monotonic() + 5
    while pending:
        for pid in pending[:]:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                pending.remove(pid)
        if pending:
            if time.monotonic() >= deadline:
                raise RuntimeError("ME-Dict did not exit within five seconds; installation stopped.")
            time.sleep(0.1)
    return was_running


def install(source, team, identity, migrate):
    if TARGET.is_symlink():
        raise RuntimeError(f"Refusing to replace a symlink: {TARGET}")
    if TARGET.exists():
        previous_signature = verify_bundle(TARGET)
        if previous_signature["adhoc"]:
            if not migrate:
                raise RuntimeError(
                    "The installed app uses ad hoc signing. Use --migrate-from-adhoc once; "
                    "macOS will require one final Accessibility authorization."
                )
        else:
            if migrate:
                raise RuntimeError("--migrate-from-adhoc only applies to an installed ad hoc app.")
            run([
                "codesign", "--verify", "--deep", "--strict", "--all-architectures",
                "-R", "=" + previous_signature["requirement"], str(source),
            ])
    elif migrate:
        raise RuntimeError("--migrate-from-adhoc requires an installed ad hoc app.")

    official_before = file_hashes(OFFICIAL)
    expected = file_hashes(source)
    token = uuid.uuid4().hex
    staged = TARGET.parent / f".ME-Dict-install-{token}.app"
    backup = TARGET.parent / f".ME-Dict-previous-{token}.app"
    replaced = False
    was_running = False
    try:
        run(["ditto", str(source), str(staged)])
        verify_signed_bundle(staged, team, identity)
        if file_hashes(staged) != expected:
            raise RuntimeError("Staged application differs from the verified build.")
        if TARGET.is_symlink():
            raise RuntimeError(f"Refusing to replace a symlink: {TARGET}")
        was_running = stop_installed_app()
        if TARGET.exists():
            TARGET.rename(backup)
        staged.rename(TARGET)
        replaced = True
        verify_signed_bundle(TARGET, team, identity)
        if file_hashes(TARGET) != expected:
            raise RuntimeError("Installed application differs from the verified build.")
        run([LSREGISTER, "-f", str(TARGET)])
        run(["open", str(TARGET)])
        if file_hashes(OFFICIAL) != official_before:
            raise RuntimeError("Official Easydict files changed during installation.")
    except Exception:
        if replaced:
            stop_installed_app()
            TARGET.rename(staged)
        if backup.exists():
            backup.rename(TARGET)
            run([LSREGISTER, "-f", str(TARGET)])
            if was_running:
                run(["open", str(TARGET)])
        raise
    finally:
        if staged.exists():
            shutil.rmtree(staged)
    if backup.exists():
        shutil.rmtree(backup)
    return {
        "installed": str(TARGET),
        "installed_files": hash_summary(expected),
        "official_files_unchanged": hash_summary(official_before),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--build-only", action="store_true", help="Build and verify without installing.")
    mode.add_argument("--install-only", action="store_true", help="Verify and install the existing build.")
    parser.add_argument(
        "--migrate-from-adhoc", action="store_true",
        help="Allow the one-time transition from the installed ad hoc app.",
    )
    args = parser.parse_args()
    if args.build_only and args.migrate_from_adhoc:
        parser.error("--migrate-from-adhoc is only meaningful when installing.")
    team, identity = signing_config()
    data = derived_data()
    source = data / "Build/Products/Release/ME-Dict.app"
    if not args.install_only:
        run([
            "xcodebuild", "build", "-workspace", "Easydict.xcworkspace",
            "-scheme", "ME-Dict", "-configuration", "Release",
            "-destination", "platform=macOS,arch=arm64",
            "ONLY_ACTIVE_ARCH=YES",
            "-derivedDataPath", str(data),
            "-onlyUsePackageVersionsFromResolvedFile", "-disableAutomaticPackageResolution",
            "-skipPackageUpdates", f"DEVELOPMENT_TEAM={team}",
            f"CODE_SIGN_IDENTITY={identity}", "CODE_SIGN_STYLE=Manual",
        ], capture=False)
    signature = verify_signed_bundle(source, team, identity)
    result = {
        "build": str(source), "team": team, "certificate_sha1": identity,
        "designated_requirement": signature["requirement"],
    }
    if args.build_only:
        result["build_files"] = hash_summary(file_hashes(source))
    else:
        result.update(install(source, team, identity, args.migrate_from_adhoc))
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, plistlib.InvalidFileException) as error:
        print(f"ME-Dict update stopped: {error}", file=sys.stderr)
        sys.exit(1)
