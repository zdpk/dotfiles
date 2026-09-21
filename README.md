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

The default is **right Command → F18 → macOS Korean/English switching**.
Caps Lock is not involved. Runtime switching needs no third-party app or custom
Swift helper. Setup uses the `osascript`, `hidutil`, `defaults`, and `launchctl`
tools included with macOS; it does not require Python or Swift build tools.

```bash
make input-sources-dry-run  # inspect the planned changes
make input-sources          # apply now and restore the mapping at login
make input-sources-status   # read configuration checks
make input-sources-restore  # restore the keyboard configuration saved before setup
```

`./bootstrap.sh` applies the same native configuration on macOS. Ubuntu does not
run keyboard modules. The input-only command does not link shell, terminal, or
editor files.

- Only ABC and Korean 2-Set are enabled as selectable keyboard sources.
- Right Command becomes a dedicated language key. It no longer acts as Command
  in shortcuts, so right Command+Space cannot invoke Command+Space Spotlight.
- Left Command and both Option keys retain their roles. There is no Option+1
  Japanese shortcut. Caps Lock settings and unrelated HID mappings are preserved.
- The previous-source shortcut is disabled. The next-source shortcut is F18.
  With exactly two sources, it toggles Korean/English.

Apply backs up the original source list, selected source, affected shortcuts,
LaunchAgents, HID mappings, and saved node configuration. It stops the old
dotfiles switcher and an active supported Karabiner user core before assigning
F18 to macOS. Fcitx keyboard sources are disabled and its process is stopped.
A running Hammerspoon must be quit before setup.
Some existing third-party sources can resist API removal. Setup then fails and
rolls back instead of ignoring the remaining source. Remove that source once in
System Settings → Keyboard → Text Input → Edit, then apply again. This was
required for the experimental Fcitx entry on m1 (macOS 26.6.2).

The native backend and `ko-en` mode are saved in `~/.config/dotfiles/`, outside
the checkout. Applying native mode on a node with the old Japanese profile
replaces that active profile with Korean/English; restore recovers the previous
profile. Reapplying an already-correct configuration does not restart services
or replace the first backup.

The installed login job runs `/usr/bin/hidutil` once and exits. It references no
checkout path and keeps no custom process running. Apple documents that HID
mappings disappear on restart or keyboard-service removal. The job reapplies
at login; run `make input-sources` after reconnecting a keyboard if needed.
[Apple TN2450](https://developer.apple.com/library/archive/technotes/tn2450/_index.html)

Backup and recovery state live in `~/.local/state/dotfiles/native-input/`.
Interrupted or incomplete changes retain that backup and require
`make input-sources-restore` before another apply. macOS may request approval
when restoring a previously enabled third-party input method; complete that
system prompt and rerun restore. Recovery merges shortcuts 60/61 with the current
preferences, preserving unrelated shortcuts changed since installation.
The separate text-input defaults described below are outside keyboard rollback.

**This makes the agreed configuration repeatable; it does not fix the known
rapid-switching IME bug.** Native F18 switching reproduced wrong initial Korean
letters in WebKit on m5. Passing configuration checks is not proof that menu
state and actual composition always agree. See the
[native setup design and validation](docs/plans/2026-09-13-native-input-setup-design.md).
`com.apple.symbolichotkeys` and `activateSettings -u` are macOS implementation
details and may need adjustment after an OS update.

### Legacy Swift configuration

The old helper remains available explicitly:

```bash
make input-sources-restore
make input-sources BACKEND=helper MODE=ko-en-ja
```

This builds the old Swift helper and restores the prior Option+1 Japanese policy.
Swift build tools are required only for that backend. `make input-diagnostics`
and its switch-event logs describe this legacy helper; use
`make input-sources-status` for the native backend.

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

## Browsers

The macOS browsers module installs the stable, Beta, and Dev channels of Google
Chrome as the `google-chrome`, `google-chrome@beta`, and `google-chrome@dev`
casks. Each channel is its own app bundle, so all three sit side by side in
`/Applications`. A cask that is already installed is left alone; Chrome updates
itself, so the setup never upgrades it.

Casks are installed with `--adopt`. A Chrome installed earlier from Google's
DMG already occupies the target path, and without it the install would abort
the bootstrap. The Chrome casks are marked `auto_updates`, so Homebrew adopts
the existing bundle as is rather than requiring its version to match the cask.
Like the fonts, the module warns and skips when Homebrew is not installed.

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
