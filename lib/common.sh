#!/usr/bin/env bash

log() {
  printf '[dotfiles] %s\n' "$*"
}

warn() {
  printf '[dotfiles] warning: %s\n' "$*" >&2
}

die() {
  printf '[dotfiles] error: %s\n' "$*" >&2
  exit 1
}

is_dry_run() {
  [ "${DOTFILES_DRY_RUN:-0}" = "1" ]
}

require_command() {
  local command_path="$1"
  [ -x "$command_path" ] || die "required command is unavailable: $command_path"
}

print_command() {
  local argument

  printf '[dotfiles] would run:'
  for argument in "$@"; do
    printf ' %q' "$argument"
  done
  printf '\n'
}

run() {
  if is_dry_run; then
    print_command "$@"
    return 0
  fi
  "$@"
}

DOTFILES_FILE_CHANGED=0

install_file_if_changed() {
  local source_path="$1"
  local target_path="$2"
  local mode="${3:-0644}"
  local target_dir

  [ -f "$source_path" ] || die "source file does not exist: $source_path"

  if [ -f "$target_path" ] && cmp -s "$source_path" "$target_path"; then
    DOTFILES_FILE_CHANGED=0
    log "unchanged: $target_path"
    return 0
  fi

  DOTFILES_FILE_CHANGED=1
  target_dir="$(dirname "$target_path")"

  if is_dry_run; then
    log "would install: $target_path"
    return 0
  fi

  mkdir -p "$target_dir"
  install -m "$mode" "$source_path" "$target_path"
  log "installed: $target_path"
}
