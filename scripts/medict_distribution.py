"""Build and validate isolated ME-Dict distribution artifacts."""

import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / ".tmp/medict-distribution"
CONFIG = ROOT / "ME-Dict.distribution.local.json"


def run(command, log=None):
    """Keep complete tool output on disk without shell expansion."""
    print(f"Running: {command[0]} {command[1] if len(command) > 1 else ''}", flush=True)
    if log:
        with Path(log).open("w") as stream:
            result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(f"Command failed ({result.returncode}); see {log}")
        return ""
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"{command[0]} failed ({result.returncode}):\n{result.stderr or result.stdout}")
    return result.stdout


def write_json(path, value):
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(path)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_config():
    if not CONFIG.is_file():
        raise RuntimeError(f"Create {CONFIG.name}; see docs/user-docs/zh/ME-Dict-distribution.md")
    config = json.loads(CONFIG.read_text())
    if not isinstance(config, dict) or set(config) != {"team_id", "certificate_sha1", "notary_profile"}:
        raise RuntimeError("Configuration requires only team_id, certificate_sha1, notary_profile.")
    if not isinstance(config["team_id"], str) or not re.fullmatch(r"[A-Z0-9]{10}", config["team_id"]):
        raise RuntimeError("Invalid team_id.")
    identity = config["certificate_sha1"]
    if not isinstance(identity, str) or not re.fullmatch(r"[A-Fa-f0-9]{40}", identity):
        raise RuntimeError("certificate_sha1 must be the fixed 40-character certificate fingerprint.")
    config["certificate_sha1"] = identity.upper()
    if not isinstance(config["notary_profile"], str) or not config["notary_profile"].strip():
        raise RuntimeError("notary_profile must name a stored Keychain profile.")
    identities = run(["security", "find-identity", "-v", "-p", "codesigning"])
    available = dict(re.findall(r'^\s*\d+\)\s+([A-F0-9]{40})\s+"([^"]+)"', identities, re.MULTILINE))
    name = available.get(config["certificate_sha1"], "")
    if not name.startswith("Developer ID Application:") or not name.endswith(f'({config["team_id"]})'):
        raise RuntimeError("A valid Developer ID Application certificate with private key for this team is required.")
    return config


def preflight(config):
    # A read-only authenticated request catches missing/invalid credentials before building.
    run(["xcrun", "notarytool", "history", "--keychain-profile", config["notary_profile"],
         "--output-format", "json"])


def derived_data():
    try:
        checkout = str(ROOT.relative_to(Path.home()))
    except ValueError:
        checkout = str(ROOT).lstrip("/")
    name = checkout.lstrip(".").replace("/", "_") + "-medict-distribution"
    return Path.home() / "Library/Developer/Xcode/DerivedData/Easydict-Agent" / name


def build(directory, version, number, config=None):
    """Never install, register, or launch the built app; never edit project signing settings."""
    command = [
        "xcodebuild", "archive" if config else "build", "-workspace", "Easydict.xcworkspace",
        "-scheme", "ME-Dict", "-configuration", "Release",
        "-destination", "generic/platform=macOS", "-derivedDataPath", str(derived_data()),
        "-onlyUsePackageVersionsFromResolvedFile", "-disableAutomaticPackageResolution",
        "-skipPackageUpdates", "ARCHS=arm64", "ONLY_ACTIVE_ARCH=YES",
        "ENABLE_HARDENED_RUNTIME=YES", "ENABLE_DEBUG_DYLIB=NO",
        "EASYDICT_RELEASE_PACKAGING=YES", f"MARKETING_VERSION={version}",
        f"CURRENT_PROJECT_VERSION={number}", "CODE_SIGN_STYLE=Manual",
    ]
    if not config:
        command += ["CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=",
                    "DEVELOPMENT_TEAM="]
        run(command, directory / "build.log")
        source = derived_data() / "Build/Products/Release/ME-Dict.app"
        app = directory / "unsigned/ME-Dict.app"
        run(["ditto", str(source), str(app)])
        return app
    archive = directory / "ME-Dict.xcarchive"
    command += ["-archivePath", str(archive), f'DEVELOPMENT_TEAM={config["team_id"]}',
                f'CODE_SIGN_IDENTITY={config["certificate_sha1"]}',
                "OTHER_CODE_SIGN_FLAGS=--timestamp", "DEPLOYMENT_POSTPROCESSING=YES"]
    run(command, directory / "archive.log")
    # Sparkle includes ad hoc-signed helpers that must be signed individually before export.
    sign_app(archive / "Products/Applications/ME-Dict.app", config, directory / "sign.log")
    options = directory / "ExportOptions.plist"
    options.write_bytes(plistlib.dumps({
        "method": "developer-id", "teamID": config["team_id"], "signingStyle": "manual",
        "signingCertificate": config["certificate_sha1"], "destination": "export",
    }))
    run(["xcodebuild", "-exportArchive", "-archivePath", str(archive),
         "-exportPath", str(directory / "export"), "-exportOptionsPlist", str(options)],
        directory / "export.log")
    return directory / "export/ME-Dict.app"


def mach_o_files(app):
    """Find embedded native code without following framework symlinks."""
    magic = {b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",
             b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca", b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xce"}
    for parent, _, names in os.walk(app, followlinks=False):
        for name in names:
            path = Path(parent) / name
            if not path.is_symlink():
                with path.open("rb") as stream:
                    if stream.read(4) in magic:
                        yield path


def sign_app(app, config, log):
    """Sign from the inside out, retaining each component's existing entitlements."""
    targets = set(mach_o_files(app)) | {app}
    for parent, directories, _ in os.walk(app, followlinks=False):
        for name in directories:
            path = Path(parent) / name
            if not path.is_symlink() and path.suffix in {".app", ".xpc", ".framework"}:
                targets.add(path)
    with log.open("w") as stream:
        for target in sorted(targets, key=lambda path: (-len(path.parts), str(path))):
            stream.write(f"Signing {target.relative_to(app.parent)}\n")
            stream.flush()
            subprocess.run(["codesign", "--force", "--sign", config["certificate_sha1"],
                            "--timestamp", "--options", "runtime",
                            "--preserve-metadata=identifier,entitlements", str(target)],
                           cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, check=True)


def signature(path, config, executable=False):
    run(["codesign", "--verify", "--strict", "--all-architectures", str(path)])
    details = subprocess.run(["codesign", "-d", "--verbose=4", str(path)],
                             text=True, capture_output=True, check=True).stderr
    required = ["Authority=Developer ID Application:", f'TeamIdentifier={config["team_id"]}', "Timestamp="]
    if executable:
        required.append("runtime")
    if not all(value in details for value in required):
        raise RuntimeError(f"Missing Developer ID, team, secure timestamp or Hardened Runtime: {path}")
    return details


def verify_certificate(path, fingerprint):
    with tempfile.TemporaryDirectory(prefix="medict-distribution-certificate-") as temporary:
        prefix = Path(temporary) / "certificate"
        run(["codesign", "-d", f"--extract-certificates={prefix}", str(path)])
        actual = hashlib.sha1(Path(f"{prefix}0").read_bytes()).hexdigest().upper()
        if actual != fingerprint:
            raise RuntimeError(f"Signing certificate differs from distribution configuration: {path}")


def verify_app(app, version, number, config=None):
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    expected = {"CFBundleIdentifier": "com.helihua.medict", "CFBundleName": "ME-Dict",
                "CFBundleDisplayName": "ME-Dict", "CFBundleExecutable": "ME-Dict",
                "CFBundleShortVersionString": version, "CFBundleVersion": number,
                "SUEnableAutomaticChecks": False, "SUAutomaticallyUpdate": False}
    for key, value in expected.items():
        if info.get(key) != value or type(info.get(key)) is not type(value):
            raise RuntimeError(f"Unexpected {key} in {app.name}.")
    if "SUFeedURL" in info or (app / "Contents/embedded.provisionprofile").exists():
        raise RuntimeError("Unexpected update feed or provisioning profile.")
    if run(["lipo", "-archs", str(app / "Contents/MacOS/ME-Dict")]).strip() != "arm64":
        raise RuntimeError("The main executable must contain only arm64.")
    count = 0
    for path in mach_o_files(app):
        if "arm64" not in run(["lipo", "-archs", str(path)]).split():
            raise RuntimeError(f"Embedded code does not support Apple Silicon: {path}")
        count += 1
        if config:
            signature(path, config, executable="executable" in run(["file", "-b", str(path)]))
    metadata = {"version": version, "build": number, "minimum_macos": info["LSMinimumSystemVersion"],
                "architecture": "arm64", "mach_o_files": count}
    if config:
        details = signature(app, config, executable=True)
        verify_certificate(app, config["certificate_sha1"])
        run(["codesign", "--verify", "--deep", "--strict", "--all-architectures", str(app)])
        entitlements = run(["codesign", "-d", "--entitlements", ":-", str(app)])
        if plistlib.loads(entitlements.encode()).get("com.apple.security.get-task-allow", False):
            raise RuntimeError("Distribution app must not allow debugger attachment.")
        metadata["cdhash"] = re.search(r"^CDHash=(.+)$", details, re.MULTILINE).group(1)
    return metadata


def create_dmg(directory, app, filename, commit):
    """Package only the build, checked-in instructions/license and exact committed sources."""
    stage = directory / "dmg-root"
    stage.mkdir()
    run(["ditto", str(app), str(stage / "ME-Dict.app")])
    (stage / "Applications").symlink_to("/Applications")
    run(["ditto", str(ROOT / "LICENSE"), str(stage / "LICENSE.txt")])
    run(["ditto", str(ROOT / "docs/user-docs/zh/ME-Dict-installation.md"), str(stage / "安装说明.txt")])
    run(["git", "archive", "--format=tar.gz", "--prefix=ME-Dict-source/",
         "-o", str(stage / "ME-Dict-source.tar.gz"), commit])
    path = directory / filename
    run(["hdiutil", "create", "-volname", "ME-Dict", "-srcfolder", str(stage),
         "-format", "UDZO", "-fs", "HFS+", str(path)], directory / "dmg.log")
    run(["hdiutil", "verify", str(path)], directory / "dmg-verify.log")
    return path
