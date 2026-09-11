# Intermittent input-switch diagnostics

The user requested diagnosis while preserving fast response and avoiding state
races. The runtime logs registered hotkey press/release, duplicate suppression,
selection before/target/readback, API and delivery timings, modifiers, Secure
Input, and TIS selection notifications. It does not capture general keys or
text. Selection executes before readback/logging; no timers, retries, polling,
synthetic events, or deferred switching were introduced. Existing suppression
behavior is preserved so the original issue remains observable.

Use `make input-diagnostics` for current service/mapping/source state and the
last 30 minutes of unified logs. `script/input-source-diagnostics.sh --follow`
views live logs without restarting the helper. Logs depend on macOS retention.

## Observed local sample

On 2026-09-11 at approximately 12:00 KST, the user reported fast, normal behavior.
18 switch requests and 18 releases were logged, including Option+1. All immediate
source readbacks matched their targets; no selection failures or ignored presses
were present. Selection API median was 22.043 ms, range 1.654-40.737 ms. These
numbers measure the TIS call, not physical-key-to-visible-composition latency.
The intermittent failure was not reproduced; its root cause is still unknown.

During deployment, immediate launchctl bootout/bootstrap returned error 5 once.
The service was confirmed absent and successfully registered on the next attempt.
This installation failure is separate from the user's intermittent key symptom.
Binary-only updates now use kickstart -k on the unchanged registered job; mode
changes still reload their changed plist. An isolated installer regression test
covers the binary-only path.

Current node stays ko-en-ja; m5-air stays ko-en. Build and run verification used
script/build_and_run.sh --verify, and the full installer suite passed locally.

The full suite also passed on m5-air. Its unchanged ko-en LaunchAgent was
restarted via kickstart -k and emitted ready mode=ko-en hotkeys=1. The local
ko-en-ja helper emitted ready with two hotkeys and recorded the user's successful
physical-key sample. Both node profiles remain outside the repository.
