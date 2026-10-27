# Korean/English switching: diagnosis and native-menu repair

Status: the Swift AX native-input-menu replacement is installed. The final
login helper passed 80 generated F18 transitions, including 20 Japanese returns.
The user completed physical-key acceptance and reported all requested steps
normal. The owned app recorded 227 physical key-down events with no Korean/ABC
layout mismatch. The failed native-bounce candidate stays withdrawn. Globe still
uses the three Apple input sources.

## Confirmed original failure

The physical-key session on 2026-10-27 recorded five instances where:

- Selected source: `com.apple.inputmethod.Korean.2SetKorean`.
- Activated app input context: `com.apple.inputmethod.Korean.2SetKorean`.
- Effective keyboard layout: `com.apple.keylayout.ABC`.
- Actual physical `d` inserted Latin `d`, instead of `ㅇ`.

The helper received the switch request and TIS selection returned successfully.
Secure Input was off. This observed failure is an input-method/layout activation
mismatch, not evidence that the physical right-Command press was missed.
Matching source IDs or a successful selection call did not establish correct
composition in the front app.

At 16:27:39 Asia/Seoul, helper request 201 selected Korean at .475, the app
observed Korean/ABC at .498, and F18 was released at .511. Physical `d` inserted
Latin at both .567 and .693. The inconsistent state outlived release and affected
successive characters. Its maximum duration without another switch was not
established. Other instances of genuinely missed key events remain unverified.

## Layout-override scope experiment

A controlled test confined to the active verification app established:

1. An app-local call set its Korean mode's layout override to ABC.
2. After 200 ms without an external correction, the app still reported ABC.
3. A separate helper called `TISSetInputMethodKeyboardLayoutOverride(2SetHangul)`.
   It returned `noErr`, but the front app still reported ABC.
4. Calling the same API inside the input app restored `2SetHangul` immediately.

This explains why merely adding the override call to an external helper did
not establish the requested front-app state. It does not identify the exact
macOS-internal trigger for the original activation failure. The API is described
in the installed SDK's `TextInputSources.h` as an input-method keyboard-layout
override used for connection/application-specific key translation.

## Why the native-bounce repair was withdrawn

The attempted repair selected Korean, selected ABC to prime the recent pair,
then sent the native previous-input-source shortcut. A controlled source/layout
prototype passed, but actual typing exposed a new regression.

The user typed in verification app PID 58055 at 20:22 Asia/Seoul:

- 20:22:23.027: `d` arrived as `ㅇ`; app source/layout were Korean/2SetHangul.
- 20:22:23.082: `k` arrived as `ㅏ`, but the source/layout had changed to ABC.
- 20:22:23.185 and .190: `s` and `l` arrived as Latin.
- Result: `abc아sl`, rather than `abc아니`.

The intermediate ABC selection interrupted the word. This candidate therefore
failed the requested typing behavior and is not an acceptable repair.

The session was initially missed because the verification window had been
reopened before analysis and its newest session was empty. Computer History
identified the earlier PID and input times; the original app-local event log
then confirmed the character-by-character transition. The user's report was valid.

## Test and diagnosis limits

Earlier generated-letter tests supplied character codes, so they did not fully
exercise physical-key translation. The latest automatic layout test also mistook
an intermediate Korean state for completion and started the next initialization
while the request was pending. Neither result overrides the physical failure.

Acceptance tests must distinguish request, intermediate source changes,
front-app layout activation, and actual committed text. Native gesture completion
and request identity must be respected before a test initializes another case.

No evidence currently proves that Japanese itself, a broken keyboard, Secure
Input, or a competing remapper caused the captured original failures. Holding
other modifiers, lost key-release events, app-specific focus changes, and the
macOS-internal activation race are separate hypotheses, not established causes.

## Current code and runtime

Right Command remains F18: Korean -> ABC; ABC/Japanese -> Korean. Globe remains
macOS Change Input Source, and shortcuts 60/61 remain disabled. The source-list
catalog correction is preserved.

The helper now chooses the exact localized source item in the native
`com.apple.TextInputMenuAgent` menu using Swift Accessibility APIs. It does not
call TISSelectInputSource, override another application's layout, select an
intermediate source, or post a synthetic activation chord. Closed menu items
can be activated directly. When macOS has discarded those items, the helper
opens that specific menu, resolves the target once, then cancels menu tracking.
AXPress can time out after opening a menu; target availability is checked rather
than assuming the timeout meant no UI change. App focus is checked before the
actual selection. Missing/ambiguous items or permission errors fail explicitly;
there is no fallback to the known faulty TIS activation path.

The user explicitly approved Swift AX menu testing and the helper's Accessibility
access. A rebuilt ad-hoc executable can invalidate that version's grant even
while Settings still shows its switch on. The final installed binary must be
re-added when necessary, restarted, and verified through the resident `ready`
log. An invoking CLI's inherited permission is insufficient evidence.

## Defects found in the AX candidate

Two separate native-menu conditions were caught before physical acceptance:

- Japanese menu construction can initially expose only `Loading…`. Reading the
  closed menu on startup/source notifications starts construction without UI
  actions. Selection waits for the source section and opens only that menu as a
  bounded fallback. It never selects another language to make items appear.
- Korean's populated menu contains `[ABC, Japanese, 2-Set Korean, separator,
  ABC, Edit Hanja Dictionary, ...]`. The second ABC is an IME command, not the
  English input source. An all-item selector rejected two matches after 37
  successful resident F18 transitions; a separate stress probe reproduced the
  exact menu after 110 selections. Selection is now confined to the source
  section before the first separator. Captured-menu regression tests verify
  that commands are excluded and ambiguous source entries are rejected.

These were defects in the new AX candidate. They do not explain the original
TIS mode/layout mismatch and must not be presented as its cause.

## Menu replacement checks

- 40 alternating native-menu selections matched the owned AppKit app's source,
  active layout and focus, with existing text preserved.
- After excluding IME commands, 200 native-menu selections across ABC, Korean
  and Japanese matched the owned app's source/layout and preserved existing text.
- The final installed LaunchAgent (PID 6425, Accessibility true) passed 80
  generated F18 switches: 20 ABC -> Korean, 20 Japanese -> Korean, and 40
  Korean -> ABC. The app's source/layout, focus and text all matched after settling.
  This exact binary matches the release build, SHA-256
  `ffb71284e6ce472afa8992f562844d86a230ba5c0e04dcf100a02a078e6fe5ab`.
- `make test` passed, including 135 Python checks, Swift policy smoke tests,
  the release build, source-catalog cross-check and isolated bootstrap tests.
  `swift test` passed all seven tests, including the captured-menu regression.
- Selecting an already-selected Korean menu item did not fix an artificial
  app-local ABC layout override. That is not claimed as a recovery mechanism.
- The automatic checks above do not establish physical-key composition. The
  separate physical acceptance below supplies that evidence.

## Final physical acceptance: 2026-10-27

The user reported all steps normal: Globe cycles ABC/Korean/Japanese, right
Command switches Korean/English, Japanese returns to Korean, and repeated
physical switching works. This is the user's confirmation of the full checklist.

The owned AppKit session PID 96051 separately recorded 227 physical key-down
events (`sourcePID=0`): 162 Korean, 61 ABC and 4 Japanese. No Korean/ABC physical
key had the wrong effective layout, and the app's Korean-layout error count
remained zero. Native Korean composition and English translation were observed
during repeated physical switching. The resident helper PID 6425 logged 66
switch requests with no `switch_failed` events during this acceptance window.
The installed SHA-256 still matched the exact automatically tested release.

Evidence was frozen at 23:07:13 Asia/Seoul. The verification window was not
reopened or cleared during acceptance. User confirmation, app-local input
records, and helper requests are preserved separately. This establishes the
requested behavior for the current Mac/session; it is not an every-app or
indefinite-duration reliability claim.

## Evidence

Under `/Users/x/.local/state/dotfiles/input-helper-20261027-nklcivc6/`:

- `cause-analysis/confirmed-mismatch.json`: original physical Korean/ABC failures.
- `cause-analysis/manual-trace.jsonl`: original event, context, and text evidence.
- `layout-fix/override-scope-proof.json`: app-local fault, external call, restoration.
- `layout-fix/real-physical-hid-failure.json`: withdrawn repair's `abc아sl` failure.
- `layout-fix/physical-hid-session-switches.log`: matching switch requests.
- `layout-fix/manual-trace.jsonl`: physical session PID 58055 and later sessions.
- `layout-fix/failed-native-bounce-main.swift`: withdrawn candidate source.
- `layout-fix/AXInputSourceProbe.swift`: authorized menu probe, exact-front-PID guard.
- `layout-fix/AX-menu-correlated.json`: 40 direct menu selections.
- `layout-fix/AX-menu-source-section-200.json`: 200 native-menu selections.
- `layout-fix/AX-F18-final-resident-80.json`: final installed helper, 80 transitions.
- `layout-fix/AX-menu-ABC-command-collision.json`: captured duplicate ABC command.

- `layout-fix/AX-physical-accepted-report.json`: physical counts, user acceptance, binary identity.
- `layout-fix/AX-physical-accepted-trace.jsonl`: frozen app-local physical session.
- `layout-fix/AX-physical-accepted-helper.log`: resident helper requests in the same window.
