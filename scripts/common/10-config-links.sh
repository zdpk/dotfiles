#!/usr/bin/env bash

set -euo pipefail

: "${DOTFILES_ROOT:?DOTFILES_ROOT must be set by bootstrap.sh}"

# shellcheck source=../../lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

HOME_DIR="${DOTFILES_HOME:-$HOME}"
CONFIG_HOME="${DOTFILES_CONFIG_HOME:-$HOME_DIR/.config}"

ensure_symlink "$DOTFILES_ROOT/config/bash/.bashrc" "$HOME_DIR/.bashrc"
ensure_symlink "$DOTFILES_ROOT/config/bash/alias.sh" "$CONFIG_HOME/bash/alias.sh"
ensure_symlink "$DOTFILES_ROOT/bin/gcloud-adc-account" "$HOME_DIR/.local/bin/gcloud-adc-account"
ensure_symlink "$DOTFILES_ROOT/config/helix" "$CONFIG_HOME/helix"
ensure_symlink "$DOTFILES_ROOT/config/wezterm/config.lua" "$CONFIG_HOME/wezterm/config.lua"
ensure_symlink "$DOTFILES_ROOT/config/zellij/config.kdl" "$CONFIG_HOME/zellij/config.kdl"
