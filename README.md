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

Both modes use one small Swift helper, started at login by a user LaunchAgent.
`hidutil` maps only physical right Command to F18. Carbon global hotkeys select
an exact Text Input Source instead of cycling through recently used languages.

- Right Command: Korean -> ABC; ABC, Japanese, or any other source -> Korean.
- `ko-en-ja` only: Option+1 selects Japanese Romaji (Hiragana).
- Right Command+Space cannot open Spotlight: the key is F18, not Command.
  It still switches language on the right Command press; Space remains Space.
- Left Command+Space remains the normal Spotlight shortcut. Both Option keys
  remain modifiers. In `ko-en`, Option+1 keeps its ordinary application behavior.
- Right Command is a dedicated language key, not a Command modifier for chords.

The two modes declare different enabled keyboard sources:

- `ko-en`: ABC and Korean 2-Set.
- `ko-en-ja`: ABC, Korean 2-Set, and Japanese Romaji.

Select once on each machine:

```bash
./setup-input-sources.sh --mode ko-en-ja   # current m1-pro: Japanese enabled
./setup-input-sources.sh --mode ko-en      # m5-air: Korean/English only
```

Successful installation saves the mode in `~/.config/dotfiles/input-mode`,
outside this repository. Later `make input-sources` or `make setup` preserves
it. Priority is `--mode` / `MODE=...`, then `DOTFILES_INPUT_MODE`, then the saved
file, then `ko-en`. Dry runs never save a mode.

The input-only entrypoint migrates Hammerspoon and applies typing defaults;
it does not link shell, terminal, or editor configuration. The full bootstrap
runs keyboard modules only on macOS. Swift build tools are required on each Mac.

```bash
make input-sources-dry-run
make input-sources
```

The installer enables the mode's sources and disables undeclared keyboard
sources. Palette sources are preserved. It clears the old native input shortcut
so F18 has exactly one owner, replaces the old right Option -> F19 mapping, and
reloads the helper when either its binary or mode changes.

The hardware mapping owns the complete `hidutil` UserKeyMapping array.
[Apple TN2450](https://developer.apple.com/library/archive/technotes/tn2450/_index.html)
documents that mappings are lost at restart or when the keyboard service is
removed. The login agent restores them at login; reapply `make input-sources`
after attaching a keyboard if its mapping is missing. Mapping readback does not
prove physical-key behavior. Test actual composition and Secure Input on each
Mac after installation or an OS upgrade.

`com.apple.symbolichotkeys` and `activateSettings -u` are undocumented migration
interfaces used to disable the previous implementation's shortcut. Runtime
switching uses Carbon and Text Input Source APIs, not that preference format.

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

On macOS, the test checks Swift policy behavior, the release build, Bash syntax, LaunchAgent plists, HID usages per mode, common configuration links, backup behavior, and repeated bootstrap execution. It also switches the Ghostty font profile out and back to confirm the link is repointed rather than backed up. Homebrew is stubbed there, so the suite never installs a cask. It also drives a machine through `ko-en` -> `ko-en-ja` -> `ko-en` against stubbed system commands to confirm that mode changes reload the helper and preserve the saved per-machine mode. If `shellcheck` is installed, it runs automatically.

The suite never calls `--apply-sources` against the real machine; only the
read-only `--check` runs there. Policy coverage lives in
`tests/InputSourcePolicySmokeTests.swift`, which is compiled directly. The
swift-testing suite under `config/macos/InputSourceSwitcher/Tests/` mirrors it
and runs only on toolchains that ship the `Testing` module — the Xcode command
line tools currently do not, so `swift test` is skipped there.
