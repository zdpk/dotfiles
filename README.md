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

The existing files under `config/` remain the source for development-tool settings. The common module links Bash, Helix, WezTerm, Ghostty, and Zellij configuration. Existing conflicting paths are moved once to `~/.local/state/dotfiles/backups/` before linking. A link this repository made itself is repointed instead, so switching a profile back and forth does not collide with the backup left by the first switch.

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

### What this rests on

Most of the mechanism is documented by Apple, but not all of it, which matters
when a macOS release breaks something.

The HID usage values come from [Technical Note TN2450][tn2450]: Right GUI
`0xE7`, Right Alt `0xE6`, F18 `0x6D`, F19 `0x6E`, each or'd with `0x700000000`.
The same note states that remappings are "lost when the system is restarted or
if the keyboard service is removed", which is why the mapping needs a
LaunchAgent at all; Apple documents no way to make them persistent, so the
LaunchAgent is this repository's answer rather than a documented one.

That second clause is a real limit. The LaunchAgent runs at login, so a
keyboard attached later in the session is not covered — reapply with
`make input-sources` after connecting one. `hidutil` has also regressed across
releases before: on macOS 14.2 it reported success while silently not applying,
and needed `sudo`. `apply_mapping` reads the mapping back and fails if it does
not match, which catches an outright rejection, but not a build that claims
success and does nothing.

The input-source handling follows `TextInputSources.h`. Exactly one keyboard
source is selected at a time and selecting a new one deselects the previous,
while zero or more palette sources may be selected — which is why only the
keyboard category is owned. An input mode can only be enabled once its parent
input method is enabled, which is why each mode is listed after its parent in
the declared set and enabled in that order.

`com.apple.symbolichotkeys` is **not documented by Apple**. The entry format
and the meaning of hotkey `60` were determined by reading what macOS writes for
its own shortcuts, corroborated against third-party write-ups; `60` is
"Select the previous input source", stock shortcut Control-Space, which matches
the entry this repository replaces.

The `parameters` array is `[character, key code, modifier mask]`. The mask is
better grounded than the container around it: the values are the documented
`NSEventModifierFlags` from `NSEvent.h`, so the function flag this setup needs
is `NSEventModifierFlagFunction`, `1 << 23`, `8388608` — not a magic number.
A bare function key is stored with that flag set, which is how macOS records
its own F14 and F15 brightness shortcuts, and the shortcut does not fire
without it.

Applying the change without a logout needs
`SystemAdministration.framework/Resources/activateSettings -u`, a private
binary with no documented alternative.

So ko-en carries a risk that a future macOS changes this format, while
ko-en-ja does not, since it uses documented Carbon and Text Input Source APIs
throughout. The module re-reads the entry after writing it and fails loudly if
it did not persist, so a break shows up during setup rather than silently.

[tn2450]: https://developer.apple.com/library/archive/technotes/tn2450/_index.html

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

## macOS text input

The second macOS module owns the global typing defaults that belong with the
language keys. It writes each value explicitly rather than inheriting whatever
the machine defaults to, so a fresh install and a hand-configured one end up in
the same state:

| Default | Value | Why |
| --- | --- | --- |
| `NSAutomaticPeriodSubstitutionEnabled` | `false` | Double-space inserts a period nobody typed |
| `NSAutomaticCapitalizationEnabled` | `false` | Capitalises identifiers meant to stay lowercase |
| `NSAutomaticQuoteSubstitutionEnabled` | `false` | Curly quotes break code, config, and shell commands |
| `NSAutomaticDashSubstitutionEnabled` | `false` | En dashes break the same literal text |
| `NSAutomaticSpellingCorrectionEnabled` | `false` | Autocorrect rewrites identifiers and command names |
| `WebAutomaticSpellingCorrectionEnabled` | `false` | WebKit keeps a separate copy of the same preference |

Period substitution is worth turning off for its failure mode rather than its
feature: the insertion is silent, happens mid-flow while switching between
Korean and English, and only surfaces later in the text, which makes it very
hard to attribute to the right cause. The rest rewrite characters that were
typed deliberately, which is wrong anywhere the text is read back literally.

Each value is written whether or not the key already exists, so a fresh VM that
has never had the key set is configured the same as a machine where someone
turned the feature back on in System Settings. Every run re-asserts all of them,
which is what makes the state hold rather than drift.

These survive a reboot without any further help. `defaults` values live in
`~/Library/Preferences/.GlobalPreferences.plist` on disk, unlike the `hidutil`
mapping, which is kernel runtime state and is why that one needs a LaunchAgent
to reapply it at every login.

Applications read these defaults when they launch, so already-running apps keep
the old behavior until restarted. `setup-input-sources.sh` applies this module
too, so a machine configured without the full bootstrap is not left behind.

## Ghostty

`config/ghostty/config` holds everything that does not depend on the machine.
The font family is deliberately not in it: it lives in one of the profiles
under `config/ghostty/fonts/`, and the common module links the selected one to
`~/.config/ghostty/font.conf`.

| Font | Family | Notes |
| --- | --- | --- |
| `firacode` (default) | FiraCode Nerd Font | |
| `geist` | GeistMono Nerd Font | The face WezTerm already uses |

Both Nerd Font casks are installed by the macOS fonts module regardless of the
selection, so switching never needs a download first. Like the input mode, the
choice is not stored in the repository, so pass it on each run:

```bash
./bootstrap.sh --font geist
make setup FONT=geist
DOTFILES_GHOSTTY_FONT=geist ./bootstrap.sh
```

Switching only repoints the link, so it takes effect on the next
`Command-Shift-,` reload rather than needing a restart.

Two details of Ghostty's configuration format are load-bearing here, and both
fail quietly rather than loudly:

`font-family` builds a fallback chain by repetition. A comma-separated list on
one line — `font-family = "FiraCode Nerd Font", "Apple SD Gothic Neo"` — is
read as a single family name that matches nothing, and Ghostty silently falls
back to its built-in font, which is why each family gets its own line. Each
profile ends with `Apple SD Gothic Neo` so Hangul does not land on whatever the
system picks. No profile sets `font-family-bold`: both families ship real bold
faces and Ghostty selects them from the family alone.

A relative `config-file` resolves against the directory of the file that
declares it, and Ghostty follows the symlink first, so `?font.conf` in the
linked config resolves inside `~/.config/ghostty/` rather than inside this
repository. That is what lets the profile be a second link instead of a
generated file. The leading `?` suppresses the error on a machine that has the
config but has not run the setup.

`theme` names a built-in theme rather than a path into `Ghostty.app`, so the
same file works on a Linux install.

## Ubuntu

Ubuntu modules use the same ordered, idempotent execution contract. No Ubuntu-only settings are configured yet.

## Test

```bash
./tests/test.sh
```

On macOS, the test checks Swift policy behavior, the release build, Bash syntax, LaunchAgent plists, HID usages per mode, common configuration links, backup behavior, and repeated bootstrap execution. It also switches the Ghostty font profile out and back to confirm the link is repointed rather than backed up. Homebrew is stubbed there, so the suite never installs a cask. It also drives a machine through `ko-en` -> `ko-en-ja` -> `ko-en` against stubbed system commands to confirm that each mode removes the other's artifacts. If `shellcheck` is installed, it runs automatically.

The suite never calls `--apply-sources` against the real machine; only the
read-only `--check` runs there. Policy coverage lives in
`tests/InputSourcePolicySmokeTests.swift`, which is compiled directly. The
swift-testing suite under `config/macos/InputSourceSwitcher/Tests/` mirrors it
and runs only on toolchains that ship the `Testing` module — the Xcode command
line tools currently do not, so `swift test` is skipped there.
