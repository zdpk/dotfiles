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

ensure_symlink() {
  local source_path="$1"
  local target_path="$2"
  local home_dir="${DOTFILES_HOME:-$HOME}"
  local state_home="${DOTFILES_STATE_HOME:-$home_dir/.local/state}"
  local backup_root="$state_home/dotfiles/backups"
  local relative_target
  local backup_path

  [ -e "$source_path" ] || die "symlink source does not exist: $source_path"

  if [ -L "$target_path" ] && [ "$(readlink "$target_path")" = "$source_path" ]; then
    log "unchanged: $target_path -> $source_path"
    return 0
  fi

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    relative_target="${target_path#"$home_dir"/}"
    backup_path="$backup_root/$relative_target"
    if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
      die "backup already exists for conflicting path: $backup_path"
    fi

    if is_dry_run; then
      log "would back up: $target_path -> $backup_path"
    else
      mkdir -p "$(dirname "$backup_path")"
      mv "$target_path" "$backup_path"
      log "backed up: $target_path -> $backup_path"
    fi
  fi

  if is_dry_run; then
    log "would link: $target_path -> $source_path"
    return 0
  fi

  mkdir -p "$(dirname "$target_path")"
  ln -s "$source_path" "$target_path"
  log "linked: $target_path -> $source_path"
}
