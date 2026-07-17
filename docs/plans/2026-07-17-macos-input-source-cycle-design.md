# macOS input-source cycle design

## Goal

Provide an idempotent Bash bootstrap repository for macOS and Ubuntu. The first macOS module turns the physical right Command key into the native Fn/Globe key so macOS cycles through enabled input sources without Hammerspoon or Karabiner.

Expected input-source order:

```text
ABC -> Korean 2-Set -> Japanese -> ABC
```

## Architecture

- `bootstrap.sh` detects Darwin or Ubuntu and runs only that platform's modules.
- `lib/common.sh` provides Bash 3.2-compatible logging, dry-run, and file-update helpers.
- `scripts/macos/` owns macOS setup modules.
- `scripts/ubuntu/` is the boundary for future Ubuntu modules.
- Modules are executed in filename order and must be safe to run repeatedly.

## macOS module

The input-source module owns three pieces of state:

1. `com.apple.HIToolbox AppleFnUsageType=1`, which assigns “Change Input Source” to Fn/Globe.
2. A single `hidutil` mapping from right Command (`0x7000000E7`) to Fn/Globe (`0xFF00000003`).
3. A per-user LaunchAgent that reapplies the mapping at login because `hidutil` mappings do not survive reboot or keyboard-service removal.

The module replaces the complete `UserKeyMapping` array with its declared mapping. This avoids accumulating duplicate entries across runs. It updates the LaunchAgent only when content changes, reloads it only when required, and always reapplies the desired mapping so reconnect recovery is deterministic.

## Safety and verification

- `./bootstrap.sh --dry-run` reports intended changes without writing.
- Unsupported Linux distributions fail rather than silently applying Ubuntu assumptions.
- The script validates required native commands before changing state.
- Input-source installation and ordering remain a documented prerequisite; the script does not rewrite Apple’s private complex input-source preference arrays.
- Verification covers Bash syntax, dry-run dispatch, generated plist validity, repeated execution, LaunchAgent registration, and the resulting `UserKeyMapping`.

Right Command becomes a native Fn modifier. Native Fn shortcuts may therefore apply when it is held with another key. Left Command remains unchanged, so left Command-Space continues to invoke Spotlight.
