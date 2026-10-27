import importlib.util
import json
import subprocess
import tempfile
import unittest
import uuid
from argparse import Namespace
from collections import Counter
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("input_source_gate", Path(__file__).resolve().parents[1] / "script/input-source-gate.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def switch_log(before, target, sequence):
    return (f"2026-10-27 21:52:59.100 Df input-source-switcher[42:abc] [Switching] "
            f"switch seq={sequence} key=primary before={before} target={target} after={before}\n")


def evidence(mode="ko-en-ja"):
    checks, logs = [], []
    for index in range(80):
        target = gate.KOREAN if index % 2 == 0 else gate.ABC
        before = gate.JAPANESE if mode == "ko-en-ja" and index % 4 == 0 else (gate.ABC if target == gate.KOREAN else gate.KOREAN)
        state = {"pid": 7, "time": 100 + index, "requestToken": str(uuid.UUID(int=index + 1)),
                 "focused": 1, "isTextResponder": 1, "source": target, "contextSource": target,
                 "layout": gate.HANGUL if target == gate.KOREAN else gate.ABC, "badKoreanKeys": 0,
                 "text": "preserved", "marked": False, "kind": "requested_snapshot"}
        checks.append({"iteration": index, "passed": True, "state": state, "settledMS": 10})
        logs.append(switch_log(before, target, 2 * index + 1))
    sources = [gate.KOREAN, gate.ABC, gate.JAPANESE] if mode == "ko-en-ja" else [gate.KOREAN, gate.ABC]
    trace = [{"pid": 7, "sourcePID": 0, "kind": "key_after_dispatch", "type": 10,
              "source": source, "contextSource": source, "layout": gate.HANGUL if source == gate.KOREAN else gate.ABC,
              "focused": 1, "isTextResponder": 1, "marked": source == gate.KOREAN,
              "badKoreanKeys": 0, "keyCode": 2, "charactersIgnoringModifiers": "ㅇ" if source == gate.KOREAN else "d"}
             for source in sources for _ in range(10)]
    physical_logs = "".join(switch_log(gate.ABC if index % 2 == 0 else gate.KOREAN,
                                      gate.KOREAN if index % 2 == 0 else gate.ABC, index + 1) for index in range(20))
    physical = {"userReported": "Completed all steps; all normal", "userConfirmedChecks": sorted(gate.MANUAL_CHECKS),
                "helperPID": 42, "testAppPID": 7, "installedSHA256": "a" * 64,
                "physicalKeyDowns": len(trace), "keysBySource": dict(Counter(row["source"] for row in trace)),
                "loggedHelperSwitchRequests": 20, "loggedHelperSwitchFailures": 0, "helperLogExitCode": 0,
                "layoutMismatchCount": 0, "maxAppKoreanLayoutErrors": 0}
    return [{"passed": True, "failure": "", "checks": checks}, "".join(logs), physical, trace, physical_logs, mode]


class EvidenceTests(unittest.TestCase):
    def test_settled_native_menu_and_physical_records_pass(self):
        self.assertEqual(gate.validate_evidence(*evidence()),
                         {"automatic_switches": 80, "physical_keys": 30, "physical_switches": 20})

    def test_two_language_mode_does_not_require_japanese_keys(self):
        self.assertEqual(gate.validate_evidence(*evidence("ko-en"))["physical_keys"], 20)

    def test_summary_pass_cannot_hide_wrong_korean_layout(self):
        data = evidence()
        data[0]["checks"][0]["state"]["layout"] = gate.ABC
        with self.assertRaisesRegex(gate.GateError, "source/layout mismatch"):
            gate.validate_evidence(*data)

    def test_final_snapshot_must_match_request_not_an_intermediate_mode(self):
        data = evidence()
        data[0]["checks"][1]["state"].update(source=gate.KOREAN, contextSource=gate.KOREAN, layout=gate.HANGUL)
        with self.assertRaisesRegex(gate.GateError, "source/layout mismatch"):
            gate.validate_evidence(*data)

    def test_duplicate_request_token_does_not_count_as_two_observations(self):
        data = evidence()
        data[0]["checks"][1]["state"]["requestToken"] = data[0]["checks"][0]["state"]["requestToken"]
        with self.assertRaisesRegex(gate.GateError, "unique request"):
            gate.validate_evidence(*data)

    def test_changed_focus_or_app_cannot_qualify(self):
        for field, value in (("focused", 0), ("pid", 99), ("isTextResponder", 0)):
            with self.subTest(field=field):
                data = evidence()
                data[0]["checks"][5]["state"][field] = value
                with self.assertRaisesRegex(gate.GateError, "owned input focus"):
                    gate.validate_evidence(*data)

    def test_request_from_a_different_helper_is_rejected(self):
        data = evidence()
        data[1] = data[1].replace("[42:", "[43:", 1)
        with self.assertRaisesRegex(gate.GateError, "process IDs"):
            gate.validate_evidence(*data)

    def test_japanese_is_never_a_primary_target(self):
        data = evidence()
        data[1] = data[1].replace("target=" + gate.KOREAN, "target=" + gate.JAPANESE, 1)
        with self.assertRaisesRegex(gate.GateError, "policy"):
            gate.validate_evidence(*data)

    def test_helper_error_cannot_be_hidden_by_zero_summary(self):
        data = evidence()
        data[4] += "switch_failed seq=100\n"
        with self.assertRaisesRegex(gate.GateError, "failed switch"):
            gate.validate_evidence(*data)

    def test_missing_japanese_routes_cannot_qualify_three_language_mode(self):
        data = evidence()
        data[1] = data[1].replace("before=" + gate.JAPANESE, "before=" + gate.ABC)
        with self.assertRaisesRegex(gate.GateError, "Japanese-to-Korean"):
            gate.validate_evidence(*data)

    def test_physical_confirmation_is_required(self):
        data = evidence()
        data[2]["userReported"] = "not tested"
        with self.assertRaisesRegex(gate.GateError, "physical-key confirmation"):
            gate.validate_evidence(*data)

    def test_incomplete_manual_checklist_is_rejected(self):
        data = evidence()
        data[2]["userConfirmedChecks"] = ["right Command Korean/English"]
        with self.assertRaisesRegex(gate.GateError, "checklist"):
            gate.validate_evidence(*data)

    def test_injected_keys_cannot_stand_in_for_physical_keys(self):
        data = evidence()
        for row in data[3]:
            row["sourcePID"] = 123
        with self.assertRaisesRegex(gate.GateError, "physical keys"):
            gate.validate_evidence(*data)

    def test_actual_latin_under_korean_is_rejected_even_with_matching_layout_id(self):
        data = evidence()
        data[3][0]["charactersIgnoringModifiers"] = "d"
        with self.assertRaisesRegex(gate.GateError, "character translation"):
            gate.validate_evidence(*data)

    def test_physical_summary_cannot_hide_raw_layout_error(self):
        data = evidence()
        data[3][0]["layout"] = gate.ABC
        with self.assertRaisesRegex(gate.GateError, "Physical source/layout"):
            gate.validate_evidence(*data)

    def test_physical_summary_must_match_raw_counts(self):
        data = evidence()
        data[2]["physicalKeyDowns"] += 1
        with self.assertRaisesRegex(gate.GateError, "summary differs"):
            gate.validate_evidence(*data)

    def test_nonfinite_json_cannot_be_approved(self):
        with self.assertRaises(gate.GateError):
            gate.load_json('{"passed":NaN}')


class HIDTests(unittest.TestCase):
    mapping = "({ HIDKeyboardModifierMappingSrc = 30064771303; HIDKeyboardModifierMappingDst = 30064771181; })"

    def test_shared_and_per_service_maps_have_the_same_identity(self):
        other = "RegistryID Key Value\n100000abc UserKeyMapping " + self.mapping + "\n100000def UserKeyMapping (null)\n100000123 UserKeyMapping " + self.mapping
        self.assertEqual(gate.hid_mapping(other), gate.hid_mapping(self.mapping))

    def test_conflicting_device_maps_are_rejected(self):
        text = "100000abc UserKeyMapping " + self.mapping + "\n100000def UserKeyMapping " + self.mapping.replace("30064771181", "99")
        with self.assertRaises(gate.GateError):
            gate.hid_mapping(text)

    def test_duplicate_or_unknown_fields_are_rejected(self):
        for extra in ("OtherField = 1;", "HIDKeyboardModifierMappingSrc = 30064771303;"):
            with self.subTest(extra=extra), self.assertRaises(gate.GateError):
                gate.hid_mapping(self.mapping.replace("}", extra + "}"))

    def test_no_mapping_or_wrong_right_command_is_rejected(self):
        for text in ("(null)", "()", "unexpected", self.mapping.replace("30064771181", "99")):
            with self.subTest(text=text), self.assertRaises(gate.GateError):
                gate.hid_mapping(text)

    def test_resident_age_supports_bsd_ps_formats(self):
        for value, seconds in (("00:42", 42), ("02:44:40", 9880), ("1-02:03:04", 93784)):
            with self.subTest(value=value):
                self.assertEqual(gate.process_age(value), seconds)
        with self.assertRaises(gate.GateError):
            gate.process_age("unknown")


class PushGateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "repo"
        self.root.mkdir()
        self.state = Path(self.tmp.name) / "state"
        self.run_git("init", "-q")
        (self.root / ".gitignore").write_text("**/.build/\n")
        self.source = self.root / gate.PACKAGE / "Sources/main.swift"
        self.source.parent.mkdir(parents=True)
        self.source.write_text("initial")
        self.base = self.commit("base")
        self.source.write_text("tested")
        self.candidate = self.commit("candidate")
        self.env = {"mode": "ko-en-ja", "backend": "helper", "binary_sha256": "a" * 64}

    def run_git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, stderr=subprocess.DEVNULL).decode().strip()

    def commit(self, title):
        self.run_git("add", ".")
        self.run_git("-c", "user.name=Gate Test", "-c", "user.email=gate@example.invalid", "commit", "-qm", title)
        return self.run_git("rev-parse", "HEAD")

    def bundle(self):
        self.state.mkdir(exist_ok=True)
        bundle = self.state / "bundle"
        bundle.mkdir()
        auto, auto_log, physical, trace, physical_log, _ = evidence()
        data = {"automatic.json": gate.canonical(auto), "automatic-helper.log": auto_log.encode(),
                "physical.json": gate.canonical(physical), "physical-trace.jsonl": b"\n".join(gate.canonical(row) for row in trace),
                "physical-helper.log": physical_log.encode(), "readiness.log": b"accessibility=true",
                "build.log": b"Build complete!", "make-test.log": b"tests passed", "swift-test.log": b"tests passed"}
        for name, content in data.items():
            (bundle / name).write_bytes(content)
        manifest = {"schema": 1, "backend": "helper", "source_manifest": gate.source_manifest(self.root, self.candidate),
                    "environment": self.env, "candidate_sha256": self.env["binary_sha256"],
                    "tests": {"make_test": True, "swift_test": True},
                    "artifacts": {name: gate.digest(content) for name, content in data.items()}}
        (bundle / "manifest.json").write_bytes(gate.canonical(manifest))
        (self.state / "approval.json").write_bytes(gate.canonical({"schema": 1, "bundle": str(bundle),
            "manifest_sha256": gate.digest(gate.canonical(manifest))}))
        return bundle

    def push(self, local=None, remote=None):
        text = f"refs/heads/main {local or self.candidate} refs/heads/main {remote or self.base}\n"
        with patch.object(gate, "environment", return_value=(self.env, "ready")):
            gate.pre_push(self.root, self.state, text)

    def test_matching_committed_native_candidate_passes(self):
        self.bundle()
        self.push()

    def test_unrelated_dirty_files_do_not_invalidate_pushed_blobs(self):
        self.bundle()
        (self.root / "README.md").write_text("unrelated local work")
        self.source.write_text("not staged or pushed")
        self.push()

    def test_different_pushed_commit_fails_despite_matching_working_tree(self):
        self.bundle()
        self.source.write_text("different pushed code")
        different = self.commit("untested")
        self.source.write_text("tested")
        with self.assertRaisesRegex(gate.GateError, "Pushed input files differ"):
            self.push(local=different)

    def test_runtime_rename_cannot_escape_protected_path_detection(self):
        self.bundle()
        self.source.rename(self.root / "moved.swift")
        moved = self.commit("rename runtime out of protected directory")
        with self.assertRaisesRegex(gate.GateError, "Pushed input files differ"):
            self.push(local=moved, remote=self.candidate)

    def test_added_keyboard_setup_module_needs_matching_approval(self):
        self.bundle()
        path = self.root / "scripts/macos/10-extra-switcher.sh"
        path.parent.mkdir(parents=True)
        path.write_text("new input setup")
        candidate = self.commit("new keyboard module")
        with self.assertRaisesRegex(gate.GateError, "Pushed input files differ"):
            self.push(local=candidate, remote=self.candidate)

    def test_added_deleted_and_mode_changed_runtime_files_invalidate_approval(self):
        for change in ("add", "delete", "mode"):
            with self.subTest(change=change):
                self.run_git("reset", "--hard", self.candidate)
                if change == "add":
                    self.source.with_name("new.swift").write_text("new")
                elif change == "delete":
                    self.source.unlink()
                else:
                    self.source.chmod(0o755)
                different = self.commit(change)
                self.assertNotEqual(gate.source_manifest(self.root, different), gate.source_manifest(self.root, self.candidate))

    def test_missing_approval_rejects_native_changes_and_new_branches(self):
        for remote in (self.base, "0" * 40):
            with self.subTest(remote=remote), self.assertRaisesRegex(gate.GateError, "No Swift-helper approval"):
                self.push(remote=remote)

    def test_changed_mode_host_binary_or_settings_invalidates_approval(self):
        self.bundle()
        for key, value in (("mode", "ko-en"), ("host", "other"), ("binary_sha256", "b" * 64), ("globe", 0)):
            with self.subTest(key=key), self.assertRaisesRegex(gate.GateError, "settings changed"):
                gate.check_approval(self.root, self.state, self.candidate, {**self.env, key: value})

    def test_modified_raw_evidence_or_manifest_is_rejected(self):
        bundle = self.bundle()
        original = (bundle / "physical.json").read_bytes()
        (bundle / "physical.json").write_bytes(b"{}")
        with self.assertRaisesRegex(gate.GateError, "evidence changed"):
            self.push()
        (bundle / "physical.json").write_bytes(original)
        (bundle / "manifest.json").write_bytes(b"{}")
        with self.assertRaisesRegex(gate.GateError, "manifest changed"):
            self.push()

    def test_active_trial_blocks_native_approval(self):
        self.bundle()
        active = self.state.parent / "input-lab/active.json"
        active.parent.mkdir()
        active.write_text("{}")
        with self.assertRaisesRegex(gate.GateError, "trial is active"):
            self.push()

    def test_multi_ref_push_rejects_one_untested_runtime(self):
        self.bundle()
        self.source.write_text("untested")
        different = self.commit("other ref")
        text = f"refs/heads/a {self.candidate} refs/heads/a {self.base}\nrefs/heads/b {different} refs/heads/b {self.base}\n"
        with patch.object(gate, "environment", return_value=(self.env, "ready")), self.assertRaises(gate.GateError):
            gate.pre_push(self.root, self.state, text)

    def test_docs_only_or_ref_deletion_needs_no_runtime_probe(self):
        (self.root / "README.md").write_text("docs")
        docs = self.commit("docs")
        with patch.object(gate, "environment") as probe:
            gate.pre_push(self.root, self.state, f"refs/heads/main {docs} refs/heads/main {self.candidate}\n")
            gate.pre_push(self.root, self.state, f"refs/heads/main {'0'*40} refs/heads/main {self.candidate}\n")
            probe.assert_not_called()

    def test_missing_legacy_validator_cannot_approve_experimental_changes(self):
        path = self.root / "config/macos/fcitx5/config"
        path.parent.mkdir(parents=True)
        path.write_text("experimental")
        candidate = self.commit("fcitx")
        with self.assertRaisesRegex(gate.GateError, "legacy input-lab validator"):
            self.push(local=candidate, remote=self.candidate)

    def test_legacy_experimental_gate_keeps_its_stdin_and_failure(self):
        legacy = self.root / "script/input-lab.py"
        legacy.parent.mkdir()
        legacy.write_text("legacy")
        text = f"refs/heads/main {self.candidate} refs/heads/main {self.base}\n"
        with patch.object(gate, "changed_names", return_value={"config/macos/fcitx5/config"}), \
             patch.object(gate.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)) as runner:
            with self.assertRaisesRegex(gate.GateError, "existing gate"):
                gate.pre_push(self.root, self.state, text)
            self.assertEqual(runner.call_args.kwargs["input"], text.encode())

    def test_malformed_or_flag_like_pre_push_records_are_rejected(self):
        for text in ("bad", "refs/main --help refs/main " + "0" * 40):
            with self.subTest(text=text), self.assertRaises(gate.GateError):
                gate.parse_updates(text)

    def approve_fixture(self, built_bytes=b"tested binary", fail_tests=False):
        agents = {}
        for label, suffix in ((gate.LABEL, ".plist"), ("dev.undervars.dotfiles.input-source-keys", ".ko-en-ja.plist")):
            path = self.root / "config/macos/LaunchAgents" / (label + suffix)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(gate.plistlib.dumps({"Label": label}))
            agents[label] = {"Label": label}
        revision = self.commit("login templates")
        data = evidence()
        sha = gate.digest(b"tested binary")
        data[2]["installedSHA256"] = sha
        folder = Path(self.tmp.name) / "evidence"
        folder.mkdir()
        files = {"automatic": gate.canonical(data[0]), "automatic_helper_log": data[1].encode(),
                 "physical_report": gate.canonical(data[2]), "physical_trace": b"\n".join(gate.canonical(row) for row in data[3]),
                 "physical_helper_log": data[4].encode()}
        arguments = {}
        for name, content in files.items():
            path = folder / name
            path.write_bytes(content)
            arguments[name] = path
        args = Namespace(revision=revision, **arguments)
        environment = {**self.env, "binary_sha256": sha, "agents": agents}
        original_command = gate.command
        calls = []

        def execute(command, root=gate.ROOT, check=True):
            if str(command[0]) == "git":
                return original_command(command, root, check)
            calls.append((command, root))
            if "build" in command:
                output = self.root / gate.PACKAGE / ".build/release/input-source-switcher"
                output.parent.mkdir(parents=True)
                output.write_bytes(built_bytes)
            if command[0] == "make":
                self.assertNotEqual(root, self.root)
                self.assertEqual((root / self.source.relative_to(self.root)).read_text(), "tested")
                if fail_tests:
                    raise gate.GateError("scoped make test failed")
            return subprocess.CompletedProcess(command, 0, b"checks passed", b"")
        return args, environment, execute, calls

    def test_approval_rebuilds_and_tests_the_committed_candidate_before_sealing(self):
        args, environment, execute, calls = self.approve_fixture()
        with patch.object(gate, "environment", return_value=(environment, "ready accessibility=true")), \
             patch.object(gate, "command", side_effect=execute):
            gate.approve(args, self.root, self.state)
        self.assertEqual([command[0] for command, _ in calls], ["/usr/bin/xcrun", "make", "/usr/bin/xcrun"])
        gate.check_approval(self.root, self.state, args.revision, environment)

    def test_installed_baseline_cannot_approve_a_different_fresh_build(self):
        args, environment, execute, _ = self.approve_fixture(built_bytes=b"new untested binary")
        with patch.object(gate, "environment", return_value=(environment, "ready")), \
             patch.object(gate, "command", side_effect=execute), \
             self.assertRaisesRegex(gate.GateError, "Freshly built candidate differs"):
            gate.approve(args, self.root, self.state)
        self.assertFalse((self.state / "approval.json").exists())

    def test_failed_scoped_tests_preserve_the_previous_approval(self):
        self.bundle()
        previous = (self.state / "approval.json").read_bytes()
        args, environment, execute, _ = self.approve_fixture(fail_tests=True)
        with patch.object(gate, "environment", return_value=(environment, "ready")), \
             patch.object(gate, "command", side_effect=execute), \
             self.assertRaisesRegex(gate.GateError, "make test failed"):
            gate.approve(args, self.root, self.state)
        self.assertEqual((self.state / "approval.json").read_bytes(), previous)

    def test_uncommitted_swift_source_cannot_be_bound_to_a_committed_candidate(self):
        args, _, _, _ = self.approve_fixture()
        self.source.write_text("uncommitted")
        with patch.object(gate, "environment") as probe, self.assertRaisesRegex(gate.GateError, "Working Swift package differs"):
            gate.approve(args, self.root, self.state)
        probe.assert_not_called()


if __name__ == "__main__":
    unittest.main()
