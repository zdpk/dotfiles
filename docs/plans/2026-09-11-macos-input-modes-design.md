# Deterministic macOS language keys

Approved requirements: right Command toggles Korean/ABC, and Japanese or unknown
sources return to Korean. Option+1 selects Japanese on ko-en-ja only. Right
Command+Space must not trigger Spotlight. Left Command+Space and both Option
modifiers retain their normal behavior. Right Command becomes a dedicated
language key. Keyboard setup runs only on macOS.

Both modes use the existing native Swift helper. hidutil maps right Command to
F18, and Carbon registers F18 plus Option+1 only when Japanese is enabled. The
helper selects exact TIS source IDs and has no remembered-primary state. Launch
agents install the same binary with explicit mode arguments. The old native F18
shortcut is disabled to prevent double handling.

The current m1-pro uses ko-en-ja; m5-air uses ko-en. The source of changes is this
local checkout; tested changes are synchronized to m5-air. Each successful setup
saves ~/.config/dotfiles/input-mode, outside Git. Explicit CLI selection wins over
the environment, saved setting, and ko-en fallback. Dry runs never save settings.

Validate policy, mode migration and persistence, installer idempotence, binary
build, actual composition after switching, Secure Input behavior, and Spotlight
chords. Readback and synthetic events cannot prove physical remapping. Existing
login agents restore hidutil at login; keyboard service removal may require
reapplication, as documented in README.

## Validation on 2026-09-11

- `make test` passed on m1-pro and m5-air (policy smoke tests, release build,
  installer idempotence, mode migrations and persistence, Bash/plist checks).
- Both installed LaunchAgents were observed running with the intended explicit
  modes; saved profiles and hidutil readback match each node's requirements.
- Physical keyboard composition, Spotlight chords, and Secure Input still need
  user confirmation. CUA-generated key presses did not exercise the registered
  global shortcuts, so those events are not treated as hardware validation.
- Previous local Hammerspoon app/config/preferences were moved to
  ~/.local/state/dotfiles/backups/hammerspoon. Input preferences and agent
  snapshots were backed up under input-modes-* on each node before installation.
