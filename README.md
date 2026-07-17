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

The first macOS module configures two dedicated language keys:

```text
physical right Command -> hidutil F18 -> native Swift helper -> English/Korean
physical right Option  -> hidutil F19 -> native Swift helper -> Japanese
```

Before applying it, enable these input sources under System Settings > Keyboard > Text Input:

1. ABC
2. Korean, 2-Set Korean
3. Japanese, Romaji

The behavior is:

```text
right Command: English -> Korean, Korean -> English
right Option:  English/Korean -> Japanese
right Command from Japanese: return to the last English/Korean source
```

The module:

- builds a small release-mode SwiftPM executable;
- registers F18/F19 with Carbon so the hotkeys survive Secure Input;
- selects exact input sources through the macOS Text Input Source API;
- owns the complete `hidutil` `UserKeyMapping` array;
- installs per-user LaunchAgents for the helper and mappings;
- reapplies the mappings immediately and at login;
- refuses an actual run while Hammerspoon, Karabiner, or the legacy Nix mapping is active.

Hammerspoon and Karabiner are not required. Left Command and left Option remain normal modifiers. Right Command-Space cannot open Spotlight because physical right Command is no longer a Command modifier. The helper is already resident, caches all input-source objects, and performs no polling, timers, retries, shell calls, or AppleScript on the key path.

## Ubuntu

Ubuntu modules use the same ordered, idempotent execution contract. No Ubuntu-only settings are configured yet.

## Test

```bash
./tests/test.sh
```

On macOS, the test checks Swift policy behavior, the release build, Bash syntax, LaunchAgent plists, HID usages, common configuration links, backup behavior, and repeated bootstrap execution. If `shellcheck` is installed, it runs automatically.
