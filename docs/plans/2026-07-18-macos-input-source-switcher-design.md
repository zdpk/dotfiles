# macOS input-source switcher design

> This document describes the currently installed prototype. It is superseded
> as a product specification by
> [keyon product requirements](./2026-07-23-keyon-prd.md). The existing behavior
> remains documented here until implementation is migrated.

## Goal

Provide fast, deterministic English, Korean, and Japanese switching with only native macOS APIs, `hidutil`, and a minimal Swift helper.

The physical-key contract is:

```text
right Command: English <-> Korean
right Option:  always Japanese
right Command while Japanese: restore the last English/Korean source
```

Left Command and left Option remain native modifiers. Right Command-Space must not invoke Spotlight.

## Event path

`hidutil` maps right Command to F18 and right Option to F19. A resident Swift executable registers both function keys with Carbon `RegisterEventHotKey`, which continues to receive registered hotkeys when Secure Input blocks event taps. The helper selects exact sources with `TISSelectInputSource`.

The hot path contains one Carbon callback and one direct TIS selection. Input-source objects are cached during process startup. It contains no subprocess launch, shell command, AppleScript, polling, timer, debounce, retry, or delayed repair.

## State

The helper stores one value: the last primary source, either ABC or Korean 2-Set.

- Before selecting Japanese, the current English/Korean source becomes the remembered source.
- Pressing right Option while already in Japanese does not overwrite the remembered source.
- Pressing right Command from Japanese or any unknown source restores the remembered source.
- A missing or invalid persisted value falls back to ABC.
- Successful primary-key switches update the remembered source.

The helper reads the actual current source only when a dedicated key is pressed. It does not observe source changes or rewrite them in the background.

## Bootstrap ownership

The macOS Bash module owns:

1. The release-mode Swift helper installed under `~/Library/Application Support/dev.undervars.dotfiles/bin/`.
2. A KeepAlive per-user LaunchAgent for the helper.
3. A per-user LaunchAgent that reapplies the complete two-entry `hidutil` mapping at login.
4. Removal of the superseded right-Command-to-Fn cycle LaunchAgent.

The module enables ABC, Korean 2-Set, and Japanese Romaji through the Text Input Source API. The input-source-only entrypoint removes Hammerspoon first; the module still refuses to apply while Hammerspoon, an active Karabiner remapper, or the legacy Nix key mapping can compete for the same keys.

## Verification

- Swift unit tests cover English/Korean toggling, Japanese return, repeated Japanese selection, and unknown-source fallback.
- Bash integration tests cover plist validity, exact HID usages, first-run installation, migration from the cycle LaunchAgent, and a no-change second run.
- The installed helper supports `--check` for source discovery and persisted-state diagnostics.
- Live verification must check direct F18/F19 delivery, physical right-side keys, left Command-Space, right Command-Space, and a real Secure Input field.
