#!/usr/bin/env python3
"""Bind Swift-helper push approval to tested Git blobs and local evidence.

The hook only reads state. Approval rebuilds and tests code, but never installs
software, injects keys, changes sources, or grants permissions.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import platform
import plistlib
import re
import socket
import subprocess
import sys
import tempfile
import uuid
from collections import Counter
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = Path.home() / ".local/state/dotfiles/input-source-gate"
PACKAGE = "config/macos/InputSourceSwitcher"
LABEL = "dev.undervars.dotfiles.input-source-switcher"
ABC = "com.apple.keylayout.ABC"
KOREAN = "com.apple.inputmethod.Korean.2SetKorean"
JAPANESE = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
HANGUL = "com.apple.keylayout.2SetHangul"
FILES = {
    "Makefile", "bootstrap.sh", "setup-input-sources.sh", "lib/common.sh",
    "scripts/macos/10-input-source-switcher.sh", "scripts/macos/20-text-input.sh",
    "scripts/macos/native-input.js", "script/native-input.sh",
    "script/input-sources-status.sh", "script/input-source-diagnostics.sh",
}
PREFIXES = (PACKAGE + "/", "config/macos/LaunchAgents/dev.undervars.dotfiles.input-source-",
            "scripts/macos/10-", "scripts/macos/20-")
EXPERIMENT_PREFIXES = (
    "config/macos/fcitx5/", "config/macos/karabiner/", "config/macos/InputSwitchLab/",
    "config/macos/InputSwitchGlobal/", "script/input_lab/", "tests/input_lab/",
    "script/input-lab", "script/input-global", "script/input-presentation",
)
MANUAL_CHECKS = {
    "Globe ABC/Korean/Japanese cycle", "right Command Korean/English",
    "Japanese to Korean", "repeated physical switching without mismatch",
}
ARTIFACTS = {
    "automatic.json", "automatic-helper.log", "physical.json", "physical-trace.jsonl",
    "physical-helper.log", "readiness.log", "build.log", "make-test.log", "swift-test.log",
}


class GateError(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise GateError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def load_json(data):
    def invalid(value):
        raise GateError("Non-finite JSON number: " + value)
    return json.loads(data, parse_constant=invalid)


def command(args, root=ROOT, check=True):
    result = subprocess.run([str(a) for a in args], cwd=root, capture_output=True)
    if check and result.returncode:
        raise GateError(f"{args[0]} failed: {result.stderr.decode(errors='replace').strip()}")
    return result


def git(root, *args):
    return command(["git", *args], root).stdout


def protected(name):
    return name in FILES or name.startswith(PREFIXES)


def tree(root, revision):
    revision = git(root, "rev-parse", "--verify", revision + "^{commit}").decode().strip()
    records = {}
    for entry in git(root, "ls-tree", "-rz", "--full-tree", revision).split(b"\0"):
        if not entry:
            continue
        metadata, name = entry.split(b"\t", 1)
        mode, kind, oid = metadata.decode().split()
        records[name.decode()] = (mode, kind, oid)
    return revision, records


def source_manifest(root, revision):
    _, records = tree(root, revision)
    return {name: {"mode": mode, "sha256": digest(git(root, "cat-file", "blob", oid))}
            for name, (mode, kind, oid) in records.items() if protected(name) and kind == "blob"}


def parse_updates(text):
    updates = []
    for line in text.splitlines():
        fields = line.split()
        require(len(fields) == 4, "Invalid pre-push input")
        _, local, _, remote = fields
        require(all(re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", oid) for oid in (local, remote)),
                "Invalid pre-push object ID")
        if set(local) != {"0"}:
            updates.append((local, remote))
    return updates


def changed_names(root, local, remote):
    if set(remote) == {"0"}:
        return set(tree(root, local)[1])
    return set(filter(None, git(root, "diff", "--no-renames", "--name-only", "-z", remote, local).decode().split("\0")))


def hid_mapping(text):
    """Normalize shared/per-service hidutil output without volatile registry IDs."""
    text = re.sub(r"^RegistryID\s+Key\s+Value\s*\n", "", text.strip())
    if re.match(r"^[0-9a-fx]+\s+UserKeyMapping\s+", text, re.I):
        pieces = re.split(r"^[0-9a-fx]+\s+UserKeyMapping\s+", text, flags=re.M | re.I)[1:]
    else:
        pieces = [text]
    maps = []
    for piece in pieces:
        piece = piece.strip()
        if piece == "(null)":
            continue
        require(piece.startswith("(") and piece.endswith(")"), "Unknown HID mapping format")
        rows = []
        for body in re.findall(r"\{([^{}]*)\}", piece):
            fields = re.findall(r"HIDKeyboardModifierMapping(Src|Dst)\s*=\s*(\d+)\s*;", body)
            values = dict(fields)
            require(len(fields) == 2 and set(values) == {"Src", "Dst"}, "Incomplete or duplicate HID mapping")
            residue = re.sub(r"HIDKeyboardModifierMapping(?:Src|Dst)\s*=\s*\d+\s*;", "", body)
            require(not residue.strip(), "Unknown HID mapping field")
            rows.append([int(values["Src"]), int(values["Dst"])])
        residue = re.sub(r"\{[^{}]*\}", "", piece[1:-1])
        require(not residue.strip(" ,\n\r\t"), "Unknown HID mapping content")
        maps.append(sorted(rows))
    require(maps and all(rows == maps[0] for rows in maps), "Missing or differing per-device HID mappings")
    require(sum(row[0] == 30064771303 for row in maps[0]) == 1 and
            [30064771303, 30064771181] in maps[0], "Right Command must map to F18")
    return maps[0]


def process_age(text):
    match = re.fullmatch(r"(?:(\d+)-)?(\d+):(\d+)(?::(\d+))?", text.strip())
    require(match, "Cannot read resident helper age")
    days, first, second, third = match.groups()
    hours, minutes, seconds = (int(first), int(second), int(third)) if third is not None else (0, int(first), int(second))
    return int(days or 0) * 86400 + hours * 3600 + minutes * 60 + seconds


def environment(root=ROOT):
    require(platform.system() == "Darwin", "Swift-helper approval requires the tested Mac")
    home = Path.home()
    profile = home / ".config/dotfiles"
    backend = (profile / "input-backend").read_text().strip()
    mode = (profile / "input-mode").read_text().strip()
    require(backend == "helper" and mode in ("ko-en", "ko-en-ja"), "Saved backend must be the Swift helper")
    binary = home / "Library/Application Support/dev.undervars.dotfiles/bin/input-source-switcher"
    sources = sorted(load_json(command([binary, "_source", "list"], root).stdout))
    wanted = [ABC, "com.apple.inputmethod.Korean", KOREAN]
    if mode == "ko-en-ja":
        wanted += ["com.apple.inputmethod.Kotoeri.RomajiTyping", JAPANESE]
    require(sources == sorted(wanted), "Enabled input-source set differs from the mode")
    fn = command(["/usr/bin/defaults", "read", "com.apple.HIToolbox", "AppleFnUsageType"], root).stdout.strip()
    require(fn == b"1", "Globe must use macOS Change Input Source")
    preferences = plistlib.loads(command(["/usr/bin/defaults", "export", "com.apple.symbolichotkeys", "-"], root).stdout)
    hotkeys = {key: preferences.get("AppleSymbolicHotKeys", {}).get(key) for key in ("60", "61", "64")}
    require(all(isinstance(hotkeys[key], dict) and hotkeys[key].get("enabled") is False for key in ("60", "61")),
            "Native shortcuts 60/61 must be disabled")
    require(isinstance(hotkeys["64"], dict) and hotkeys["64"].get("enabled") is True,
            "Left Command+Space Spotlight must remain enabled")
    require(hotkeys["64"].get("value", {}).get("parameters", [])[1:] == [49, 1048576],
            "Spotlight must retain left Command+Space")
    mappings = hid_mapping(command(["/usr/bin/hidutil", "property", "--get", "UserKeyMapping"], root).stdout.decode())
    agents = {}
    for label in (LABEL, "dev.undervars.dotfiles.input-source-keys"):
        agents[label] = plistlib.loads((home / "Library/LaunchAgents" / (label + ".plist")).read_bytes())
    service = command(["/bin/launchctl", "print", f"gui/{os.getuid()}/{LABEL}"], root).stdout.decode()
    match = re.search(r"^\tpid = (\d+)\s*$", service, re.M)
    require("\tstate = running" in service and match, "Installed helper LaunchAgent is not running")
    pid = int(match[1])
    process = command(["/bin/ps", "-ww", "-p", str(pid), "-o", "command="], root).stdout.decode().strip()
    require(process == f"{binary} --run {mode}", "Resident helper path/mode differs from the installed candidate")
    predicate = f'subsystem == "{LABEL}" AND processID == {pid} AND eventMessage BEGINSWITH "ready"'
    age = process_age(command(["/bin/ps", "-p", str(pid), "-o", "etime="], root).stdout.decode())
    started = (datetime.now() - timedelta(seconds=age + 2)).strftime("%Y-%m-%d %H:%M:%S")
    readiness = command(["/usr/bin/log", "show", "--start", started, "--style", "compact", "--predicate", predicate], root).stdout.decode()
    ready_lines = [line for line in readiness.splitlines() if f"input-source-switcher[{pid}:" in line and "ready mode=" in line]
    require(ready_lines and f"mode={mode} hotkeys=1 mechanism=native_input_menu accessibility=true" in ready_lines[-1],
            "No resident native-menu Accessibility readiness record; restart the helper and recheck")
    remappers = [name for name in ("Hammerspoon", "Fcitx5", "karabiner_grabber", "karabiner_console_user_server")
                 if command(["/usr/bin/pgrep", "-x", name], root, check=False).returncode == 0]
    require(not remappers, "Another user input remapper is running")
    return ({"host": socket.gethostname(), "os_build": command(["/usr/bin/sw_vers", "-buildVersion"], root).stdout.decode().strip(),
             "backend": backend, "mechanism": "native_input_menu", "mode": mode,
             "binary_sha256": digest(binary.read_bytes()), "sources": sources, "globe": 1,
             "hotkeys": hotkeys, "hid_mapping": mappings, "agents": agents}, readiness)


def switch_requests(text, pid):
    require("switch_failed" not in text, "Helper log contains a failed switch")
    requests = []
    pattern = r"input-source-switcher\[(\d+):[^\]]+\].*\bswitch seq=(\d+) key=primary before=(\S+) target=(\S+)"
    for match in re.finditer(pattern, text):
        owner, sequence, before, target = match.groups()
        require(int(owner) == pid, "Helper evidence mixes resident process IDs")
        require(target == (ABC if before == KOREAN else KOREAN), "Right-Command target violates Korean/English policy")
        requests.append((int(sequence), before, target))
    require(len({row[0] for row in requests}) == len(requests), "Duplicate switch request evidence")
    require([row[0] for row in requests] == sorted(row[0] for row in requests), "Out-of-order switch request evidence")
    return requests


def validate_evidence(automatic, auto_log, physical, trace, physical_log, mode):
    require(mode in ("ko-en", "ko-en-ja"), "Unknown Swift-helper mode")
    require(isinstance(automatic, dict) and automatic.get("passed") is True and automatic.get("failure") == "",
            "Automatic F18 run did not pass")
    checks = automatic.get("checks", [])
    require(isinstance(checks, list) and len(checks) >= 40, "Incomplete automatic F18 run")
    require(all(isinstance(check, dict) for check in checks), "Malformed automatic case")
    require(isinstance(physical, dict) and physical.get("userReported") == "Completed all steps; all normal",
            "Missing explicit successful physical-key confirmation")
    required_manual = MANUAL_CHECKS if mode == "ko-en-ja" else {"right Command Korean/English", "repeated physical switching without mismatch"}
    require(required_manual <= set(physical.get("userConfirmedChecks", [])), "Physical checklist is incomplete")
    pid, app_pid = physical.get("helperPID"), physical.get("testAppPID")
    require(type(pid) is int and pid > 0 and type(app_pid) is int and app_pid > 0, "Missing tested process identity")
    requests = switch_requests(auto_log, pid)
    require(len(requests) == len(checks), "Automatic helper requests do not match settled snapshots")
    tokens = set()
    previous_time = 0
    initial_text = checks[0].get("state", {}).get("text")
    require(isinstance(initial_text, str), "Missing automatic input-preservation evidence")
    for index, (check, (_, before, target)) in enumerate(zip(checks, requests)):
        state = check.get("state", {})
        token = state.get("requestToken")
        require(type(check.get("iteration")) is int and check.get("iteration") == index and check.get("passed") is True,
                "Incomplete or out-of-order automatic case")
        try:
            valid_token = isinstance(token, str) and str(uuid.UUID(token)) == token.lower()
        except ValueError:
            valid_token = False
        require(valid_token and token.lower() not in tokens,
                "Automatic snapshots must have unique request tokens")
        tokens.add(token.lower())
        when = state.get("time")
        require(type(when) in (float, int) and math.isfinite(when) and when > previous_time, "Invalid automatic snapshot timing")
        previous_time = when
        require(state.get("pid") == app_pid and state.get("focused") == 1 and state.get("isTextResponder") == 1,
                "Automatic evidence lost its owned input focus")
        require(state.get("source") == target and state.get("contextSource") == target and
                state.get("layout") == (HANGUL if target == KOREAN else ABC), "Automatic source/layout mismatch")
        require(state.get("kind") == "requested_snapshot" and state.get("text") == initial_text and state.get("marked") is False,
                "Automatic snapshots did not preserve settled input")
        elapsed = check.get("settledMS")
        require(type(elapsed) in (int, float) and math.isfinite(elapsed) and 0 <= elapsed <= 1000,
                "Invalid automatic completion timing")
        require(state.get("badKoreanKeys") == 0, "Automatic run recorded Korean layout errors")
    routes = Counter((before, target) for _, before, target in requests)
    require(routes[(ABC, KOREAN)] >= 10 and routes[(KOREAN, ABC)] >= 20, "Automatic Korean/English route coverage is incomplete")
    if mode == "ko-en-ja":
        require(routes[(JAPANESE, KOREAN)] >= 10, "Automatic Japanese-to-Korean coverage is incomplete")
    require(isinstance(trace, list) and trace, "Missing raw physical trace")
    require(all(isinstance(row, dict) for row in trace), "Malformed physical trace")
    require(all(row.get("pid") == app_pid for row in trace), "Physical trace mixes test sessions")
    keys = [row for row in trace if row.get("kind") == "key_after_dispatch" and row.get("type") == 10 and row.get("sourcePID") == 0]
    counts = Counter(row.get("source") for row in keys)
    wanted = {ABC, KOREAN, JAPANESE} if mode == "ko-en-ja" else {ABC, KOREAN}
    require(len(keys) >= 20 and wanted <= set(counts), "Missing physical keys in the required input sources")
    for row in keys:
        source = row.get("source")
        require(source in wanted and row.get("focused") == 1 and row.get("isTextResponder") == 1,
                "Physical key did not belong to the owned input field")
        require(row.get("contextSource") == source and row.get("layout") == (HANGUL if source == KOREAN else ABC),
                "Physical source/layout mismatch")
        # Actual physical characters are separate from the selected mode. These
        # keys include the original dksl reproducer and the user's repeated z.
        pairs = {2: ("d", "ㅇ"), 40: ("k", "ㅏ"), 1: ("s", "ㄴ"), 37: ("l", "ㅣ"), 6: ("z", "ㅋ")}
        modifiers = row.get("flags", 0)
        if source in (ABC, KOREAN) and row.get("keyCode") in pairs and not modifiers & ((1 << 18) | (1 << 19) | (1 << 20)):
            expected = pairs[row["keyCode"]][source == KOREAN]
            require(row.get("charactersIgnoringModifiers", "").casefold() == expected,
                    "Physical character translation differs from the selected layout")
    require(max(row.get("badKoreanKeys", -1) for row in trace) == 0, "Physical trace recorded Korean layout errors")
    require(any(row.get("marked") is True for row in keys if row.get("source") == KOREAN), "Missing real Korean composition evidence")
    physical_requests = switch_requests(physical_log, pid)
    require(len(physical_requests) >= 20, "Physical switching repetition is incomplete")
    require(physical.get("physicalKeyDowns") == len(keys) and physical.get("keysBySource") == dict(counts),
            "Physical summary differs from raw keys")
    require(physical.get("loggedHelperSwitchRequests") == len(physical_requests) and
            physical.get("loggedHelperSwitchFailures") == 0 and physical.get("helperLogExitCode") == 0 and
            physical.get("layoutMismatchCount") == 0 and physical.get("maxAppKoreanLayoutErrors") == 0,
            "Physical summary differs from successful raw switching evidence")
    return {"automatic_switches": len(checks), "physical_keys": len(keys), "physical_switches": len(physical_requests)}


def read_bundle(bundle):
    manifest = load_json((bundle / "manifest.json").read_bytes())
    require(manifest.get("schema") == 1 and manifest.get("backend") == "helper", "Unsupported Swift approval schema")
    require(set(manifest.get("artifacts", {})) == ARTIFACTS, "Approval is missing evidence artifacts")
    for name, expected in manifest["artifacts"].items():
        require(digest((bundle / name).read_bytes()) == expected, "Approved evidence changed: " + name)
    require(manifest.get("tests") == {"make_test": True, "swift_test": True}, "Scoped tests did not pass")
    require(manifest.get("candidate_sha256") == manifest.get("environment", {}).get("binary_sha256"),
            "Tested build and installed binary identity differ")
    return manifest


def check_approval(root, state, revision, live_environment=None):
    require(not (state.parent / "input-lab/active.json").exists(),
            "Input trial is active or needs recovery")
    pointer = state / "approval.json"
    require(pointer.is_file(), "No Swift-helper approval. Run script/input-source-gate.py approve with accepted evidence")
    approval = load_json(pointer.read_bytes())
    require(approval.get("schema") == 1 and isinstance(approval.get("bundle"), str), "Malformed Swift approval pointer")
    bundle = Path(approval["bundle"]).resolve()
    require(state.resolve() in bundle.parents, "Approval bundle must remain inside local gate state")
    require(digest((bundle / "manifest.json").read_bytes()) == approval.get("manifest_sha256"), "Approval manifest changed")
    manifest = read_bundle(bundle)
    require(source_manifest(root, revision) == manifest.get("source_manifest"), "Pushed input files differ from the tested Git tree")
    current = live_environment if live_environment is not None else environment(root)[0]
    require(current == manifest.get("environment"), "Tested helper binary, host, OS, mode or input settings changed")
    physical = load_json((bundle / "physical.json").read_bytes())
    require(physical.get("installedSHA256") == current.get("binary_sha256"), "Physical test belongs to a different binary")
    validate_evidence(load_json((bundle / "automatic.json").read_bytes()), (bundle / "automatic-helper.log").read_text(),
                      physical, [load_json(line) for line in (bundle / "physical-trace.jsonl").read_text().splitlines()],
                      (bundle / "physical-helper.log").read_text(), current["mode"])
    return manifest


def export_revision(root, revision, destination):
    _, records = tree(root, revision)
    for name, (mode, kind, oid) in records.items():
        require(kind == "blob", "Scoped tests do not support Git submodules")
        path = destination / name
        require(destination.resolve() in path.resolve().parents, "Unsafe path in tested tree")
        path.parent.mkdir(parents=True, exist_ok=True)
        data = git(root, "cat-file", "blob", oid)
        if mode == "120000":
            target = data.decode()
            require(destination.resolve() in (path.parent / target).resolve().parents, "Unsafe test-tree symlink")
            path.symlink_to(target)
        else:
            path.write_bytes(data)
            path.chmod(0o755 if mode == "100755" else 0o644)


def verify_package(root, manifest):
    names = set(filter(None, git(root, "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", PACKAGE).decode().split("\0")))
    require(names == {name for name in manifest if name.startswith(PACKAGE + "/")}, "Swift package differs from the candidate Git tree")
    require(all(not (root / name).is_symlink() and digest((root / name).read_bytes()) == manifest[name]["sha256"] for name in names),
            "Working Swift package differs from the candidate Git tree")


def approve(args, root, state):
    require(not (state.parent / "input-lab/active.json").exists(), "Input trial is active or needs recovery")
    revision, _ = tree(root, args.revision)
    original = source_manifest(root, revision)
    # Compile only source files belonging to this immutable candidate. Dirty
    # Makefile/docs and unrelated untracked experiments are not build inputs.
    verify_package(root, original)
    before, readiness = environment(root)
    templates = {
        LABEL: "config/macos/LaunchAgents/" + LABEL + ".plist",
        "dev.undervars.dotfiles.input-source-keys":
            "config/macos/LaunchAgents/dev.undervars.dotfiles.input-source-keys." + before["mode"] + ".plist",
    }
    for label, name in templates.items():
        desired = plistlib.loads(git(root, "show", revision + ":" + name).replace(b"__INPUT_MODE__", before["mode"].encode()))
        require(before["agents"][label] == desired, "Installed login configuration differs from the candidate: " + label)
    inputs = {"automatic.json": args.automatic, "automatic-helper.log": args.automatic_helper_log,
              "physical.json": args.physical_report, "physical-trace.jsonl": args.physical_trace,
              "physical-helper.log": args.physical_helper_log}
    data = {name: path.read_bytes() for name, path in inputs.items()}
    physical = load_json(data["physical.json"])
    require(physical.get("installedSHA256") == before["binary_sha256"], "Physical evidence belongs to a different installed binary")
    summary = validate_evidence(load_json(data["automatic.json"]), data["automatic-helper.log"].decode(), physical,
                                [load_json(line) for line in data["physical-trace.jsonl"].splitlines()],
                                data["physical-helper.log"].decode(), before["mode"])
    build = command(["/usr/bin/xcrun", "swift", "build", "--package-path", root / PACKAGE,
                     "--configuration", "release", "--product", "input-source-switcher"], root)
    binary = root / PACKAGE / ".build/release/input-source-switcher"
    require(digest(binary.read_bytes()) == before["binary_sha256"], "Freshly built candidate differs from the physically tested/installed binary")
    data["build.log"] = build.stdout + build.stderr
    with tempfile.TemporaryDirectory(prefix="dotfiles-input-gate-tests-") as tmp:
        destination = Path(tmp)
        export_revision(root, revision, destination)
        for name, cmd in (("make-test.log", ["make", "test"]),
                          ("swift-test.log", ["/usr/bin/xcrun", "swift", "test", "--package-path", PACKAGE])):
            print("Checking scoped candidate: " + " ".join(cmd), flush=True)
            result = command(cmd, destination)
            data[name] = result.stdout + result.stderr
    after, _ = environment(root)
    require(before == after, "Candidate environment changed during validation")
    verify_package(root, original)
    data["readiness.log"] = readiness.encode()
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    bundle = Path(tempfile.mkdtemp(prefix="swift-", dir=state))
    for name, content in data.items():
        (bundle / name).write_bytes(content)
        (bundle / name).chmod(0o600)
    manifest = {"schema": 1, "backend": "helper", "tested_revision": revision, "source_manifest": original,
                "environment": before, "candidate_sha256": digest(binary.read_bytes()),
                "summary": summary, "tests": {"make_test": True, "swift_test": True},
                "artifacts": {name: digest(content) for name, content in data.items()}}
    (bundle / "manifest.json").write_bytes(canonical(manifest))
    pointer = {"schema": 1, "bundle": str(bundle), "manifest_sha256": digest(canonical(manifest))}
    with tempfile.NamedTemporaryFile(prefix="approval-", dir=state, delete=False) as output:
        output.write(canonical(pointer))
        temporary = Path(output.name)
    os.replace(temporary, state / "approval.json")
    print(f"APPROVED Swift helper {revision[:12]}: {summary}")


def pre_push(root, state, text):
    updates = parse_updates(text)
    native = []
    experimental = False
    for local, remote in updates:
        names = changed_names(root, local, remote)
        if any(protected(name) for name in names):
            native.append(local)
        experimental |= any(name.startswith(EXPERIMENT_PREFIXES) for name in names)
    if native or experimental:
        require(not (state.parent / "input-lab/active.json").exists(), "Input trial is active or needs recovery")
    if native:
        current, _ = environment(root)
        for revision in set(native):
            check_approval(root, state, revision, current)
        print("Swift-helper push gate: tested Git blobs, binary, configuration and evidence match.")
    if experimental:
        legacy = root / "script/input-lab.py"
        require(legacy.is_file(), "Experimental Fcitx changes require the legacy input-lab validator")
        result = subprocess.run([sys.executable, str(legacy), "push-gate"], cwd=root, input=text.encode())
        require(result.returncode == 0, "Experimental input changes did not pass their existing gate")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", type=Path, default=STATE)
    commands = parser.add_subparsers(dest="command", required=True)
    record = commands.add_parser("approve")
    record.add_argument("--revision", default="HEAD")
    for name in ("automatic", "automatic-helper-log", "physical-report", "physical-trace", "physical-helper-log"):
        record.add_argument("--" + name, type=Path, required=True)
    check = commands.add_parser("check")
    check.add_argument("--revision", default="HEAD")
    push = commands.add_parser("pre-push")
    push.add_argument("remote", nargs="?")
    push.add_argument("remote_url", nargs="?")
    args = parser.parse_args(argv)
    try:
        if args.command == "approve":
            approve(args, ROOT, args.state_dir)
        elif args.command == "check":
            check_approval(ROOT, args.state_dir, args.revision)
            print("Swift-helper approval matches this commit and runtime.")
        else:
            pre_push(ROOT, args.state_dir, sys.stdin.read())
    except (GateError, OSError, ValueError, KeyError, TypeError) as error:
        print("Input-source push gate: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
