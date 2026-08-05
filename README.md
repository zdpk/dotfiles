# dotfiles

Idempotent Bash bootstrap for macOS and Ubuntu.

## Run

Clone the repository and inspect the planned changes:

```bash
git clone https://github.com/zdpk/dotfiles.git ~/ws/personal/dotfiles
cd ~/ws/personal/dotfiles
./bootstrap.sh --dry-run
```

Apply the current platform configuration:

```bash
./bootstrap.sh
```

`bootstrap.sh` runs `scripts/common/` first. It then detects macOS or Ubuntu and runs only that platform's numbered modules. Other Linux distributions fail explicitly.

The existing files under `config/` remain the source for development-tool settings. The common module links Bash, Helix, WezTerm, and Zellij configuration. Existing conflicting paths are moved once to `~/.local/state/dotfiles/backups/` before linking.

The repository is Bash-first. The former Nix configuration has been removed. Platform-specific automation belongs under `scripts/macos/` and `scripts/ubuntu/`.

## macOS input-source keys

The first macOS module turns the right-side modifier keys into dedicated
language keys. It has two modes, because not every machine needs Japanese.

A mode is one declaration covering both halves of the setup: which keyboard
input sources exist, and how switching between them happens. The source set
decides the mechanism — two sources fit the native shortcut, three do not.

| Mode | Keyboard input sources | Keys | Switching is performed by |
| --- | --- | --- | --- |
| `ko-en` (default) | ABC, Korean 2-Set | right Command | macOS itself |
| `ko-en-ja` | ABC, Korean 2-Set, Japanese Romaji | right Command, right Option | a resident Swift helper |

Select the mode with `--mode`, the `MODE` variable, or `DOTFILES_INPUT_MODE`.
The mode is not stored in the repository, so pass it on each run:

```bash
./bootstrap.sh                            # ko-en
./bootstrap.sh --mode ko-en-ja
make setup MODE=ko-en-ja
DOTFILES_INPUT_MODE=ko-en-ja ./bootstrap.sh
```

For an input-source-only setup that does not link the shell, editor, terminal,
or multiplexer configuration, use the dedicated entrypoint. It removes
Hammerspoon first, moving existing configuration and preferences under
`~/.local/state/dotfiles/backups/hammerspoon/`:

```bash
./setup-input-sources.sh --dry-run
./setup-input-sources.sh --mode ko-en-ja
```

Both modes own the complete `hidutil` `UserKeyMapping` array, install a per-user
LaunchAgent that reapplies the mapping at login, and refuse an actual run while
Hammerspoon, Karabiner, or the legacy Nix mapping is active. Left Command and
left Option remain normal modifiers. Right Command-Space cannot open Spotlight
because physical right Command is no longer a Command modifier.

Switching modes is safe in either direction: each mode removes the other's
artifacts before installing its own.

### The input-source list

dotfiles owns the keyboard input-source list the way it owns `UserKeyMapping`.
Both modes run the same tool, which enables everything the mode declares and
disables any other enabled *keyboard* source, reporting each removal:

```text
[dotfiles] disabled input source: com.apple.keylayout.Dvorak
```

Palette sources — the character viewer, press-and-hold, the Japanese 50-on
palette — are a separate Text Input Source category, are never part of the
keyboard rotation, and are left alone.

Owning the list is what makes `ko-en` correct rather than merely convenient: its
shortcut walks the most recently used sources, so it is an exact Korean/English
toggle only while those are the only two keyboard sources.

Because there is no built-in macOS command for this, both modes need the Swift
toolchain at setup time. Only `ko-en-ja` installs a binary or leaves a process
running.

### ko-en

```text
physical right Command -> hidutil F18 -> macOS "select the previous input source"
```

Nothing is installed and nothing stays resident. The tool is built, run once to
apply the source list, and left in the build directory. The module then binds
the stock `Select the previous input source` shortcut (symbolic hotkey `60`) to
a bare F18 and lets macOS perform the switch.

### ko-en-ja

```text
physical right Command -> hidutil F18 -> resident Swift helper -> English/Korean
physical right Option  -> hidutil F19 -> resident Swift helper -> Japanese
```

```text
right Command: English -> Korean, Korean -> English
right Option:  English/Korean -> Japanese
right Command from Japanese: return to the last English/Korean source
```

Three sources cannot be driven by a history-based shortcut, so the same
executable is installed and kept resident by a second LaunchAgent. It registers
F18/F19 with Carbon (so the hotkeys survive Secure Input) and selects exact
input sources through the Text Input Source API. It caches all input-source
objects and performs no polling, timers, retries, shell calls, or AppleScript on
the key path. This mode also restores the native shortcut to its stock disabled
state so that F18 is not handled twice.

## Ubuntu

Ubuntu modules use the same ordered, idempotent execution contract. No Ubuntu-only settings are configured yet.

## Test

```bash
./tests/test.sh
```

On macOS, the test checks Swift policy behavior, the release build, Bash syntax, LaunchAgent plists, HID usages per mode, common configuration links, backup behavior, and repeated bootstrap execution. It also drives a machine through `ko-en` -> `ko-en-ja` -> `ko-en` against stubbed system commands to confirm that each mode removes the other's artifacts. If `shellcheck` is installed, it runs automatically.

The suite never calls `--apply-sources` against the real machine; only the
read-only `--check` runs there. Policy coverage lives in
`tests/InputSourcePolicySmokeTests.swift`, which is compiled directly. The
swift-testing suite under `config/macos/InputSourceSwitcher/Tests/` mirrors it
and runs only on toolchains that ship the `Testing` module — the Xcode command
line tools currently do not, so `swift test` is skipped there.
