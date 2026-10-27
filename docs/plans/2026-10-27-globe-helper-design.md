# Globe and right Command input switching

The requested configuration uses Apple ABC, Korean 2-Set, and Japanese Romaji.
Globe/Fn cycles those sources through macOS. Right Command maps to F18 and the
existing Swift helper selects ABC from Korean, or Korean from ABC/Japanese.
The helper never selects Japanese and no longer registers Option+1.

Setup must not reuse TIS's includeAll cache to decide which sources to disable.
On macOS 27.0.1, an active-first query returned only the five declared parent and
mode entries, while a query after includeAll also returned inactive Ainu, Kana,
and Fcitx modes. Source enable/disable operations now run in fresh helper clients;
each captures effective sources before loading the complete catalog. The resident
hotkey path selects the exact native input-menu item with Swift AX, without
child processes, an intermediate source, or a synthetic activation chord. It
requires Accessibility access for the final installed helper executable.

## Installation and persistence

Restore an active native installation before selecting the helper. Preserve
the original native backup and save a snapshot of the current configuration
before migrating. Newer macOS releases print HID mappings per service; recovery
accepts identical active maps and rejects conflicting device mappings.

Run `make input-sources BACKEND=helper MODE=ko-en-ja`. The installer enables the
two parent IMEs and exactly three selectable sources, sets Globe to Change Input
Source, disables shortcuts 60/61 to avoid sharing F18, installs the helper
and login HID mapping, then saves the backend/mode outside Git. Subsequent
bootstrap runs retain the local selection. Other machines are not changed.

## Validation

Run the existing policy tests and isolated setup tests, including native-backend
recovery, F18 conflict removal, Globe setup, reapplication, and node persistence.
On the current Mac, verify the installed binary and LaunchAgent, the enabled
source catalog, saved mode, Fn preference, and native shortcut state.

Exercise the running helper's F18 through a dedicated test input window with a
foreground guard. Cover ABC to Korean, Korean to ABC, and Japanese to Korean.
Check Japanese remains selectable and Globe is configured for all sources.
Do not equate injected F18 with a physical right Command or Globe press, or source
ID readback with correct composed text. Record any unverified physical-key or
composition checks in the final result.

## Current validation: 2026-10-27

Subsequent physical-key testing reproduced Korean selection with an ABC layout
and Latin input. The attempted native-bounce repair also failed actual typing
and was withdrawn from code and runtime. The final native-menu replacement passes
200 menu selections and 80 generated F18 transitions through the installed login
helper, including 20 Japanese returns. The user completed the physical-key
checklist and confirmed all steps normal. The owned app recorded 227 physical
key-down events across all three sources with no Korean/ABC layout mismatch;
66 resident helper requests were logged without errors. See the separate
physical-acceptance section in the diagnosis for evidence and scope.
The earlier automatic passes below are historical and limited to their stated
injection scope; they do not establish a working physical-key configuration.
See [the confirmed diagnosis](2026-10-27-right-command-layout-desync.md).

- `make test` passed: native setup tests, 135 Python regression checks, Swift
  policy smoke tests, the release build, source-catalog cross-check, and isolated
  bootstrap tests.
- The current Mac saves `helper` / `ko-en-ja`; its helper has one registered
  hotkey and runs through the installed login agent. Globe is Change Input Source.
- With the user's explicit HID/CGEvent authorization and foreground test window,
  generated F18 events selected Korean from ABC/Japanese and ABC from Korean.
  Actual Korean `dksl` became `아니`; ABC input remained `abc`.
- Japanese `a` became `あ`, and `nihongo` became `日本語` through live conversion.
  Return confirmed the Japanese text with no marked composition remaining.
  Both pending hiragana and committed Japanese text survived switching to Korean.
  The earlier automated Roman-letter results were not reproduced by the clean
  NSTextView harness with correct key/ASCII pairs and IME completion waits.
- The native next-source action completed Korean -> ABC -> Japanese -> Korean.
  Each stage produced the expected actual text, including Japanese composition.
- The UI automation tool rejects Fn/Globe key names; synthetic Fn flags did not
  invoke Globe switching. The native cycle was therefore exercised through a
  temporary Control+Option+Space binding. F18 was injected directly, while the
  installed right Command -> F18 mapping was verified separately. Neither test
  claims an actual physical Globe or right Command press. The existing virtual
  HID driver was not ready, and no new driver was installed.
- Final helper setup restored shortcuts 60/61 to disabled, retained left
  Command+Space Spotlight, and left Korean selected. The saved backend/mode,
  installed helper, login mappings, and Globe preference passed final readback.
  No other machine has been changed.

The two final runtime reports have `passed: true` and preserve expected/actual
text, source transitions, and test scope:

- `/Users/x/.local/state/dotfiles/input-helper-20261027-nklcivc6/focused-verification/ime-integration.json`
- `/Users/x/.local/state/dotfiles/input-helper-20261027-nklcivc6/focused-verification/native-cycle.json`

These are ordinary-speed AppKit checks. They do not establish physical-key,
every-application, or high-speed typing coverage.
