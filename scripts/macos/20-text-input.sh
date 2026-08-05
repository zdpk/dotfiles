#!/usr/bin/env bash

set -euo pipefail

: "${DOTFILES_ROOT:?DOTFILES_ROOT must be set by bootstrap.sh}"

# shellcheck source=../../lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

DEFAULTS="${DOTFILES_DEFAULTS:-/usr/bin/defaults}"
GLOBAL_DOMAIN=-g

require_command "$DEFAULTS"
[ "$(uname -s)" = "Darwin" ] || die "the text-input module requires macOS"

# Writes the value explicitly rather than trusting the machine default, so a
# fresh install lands in the same state as one that was configured by hand.
apply_boolean_default() {
  local key="$1"
  local wanted="$2"
  local description="$3"
  local wanted_value
  local current

  case "$wanted" in
    true)
      wanted_value=1
      ;;
    false)
      wanted_value=0
      ;;
    *)
      die "invalid boolean for $key: $wanted"
      ;;
  esac

  current="$("$DEFAULTS" read "$GLOBAL_DOMAIN" "$key" 2>/dev/null || true)"

  if [ "$current" = "$wanted_value" ]; then
    log "unchanged: $description"
    return 0
  fi

  run "$DEFAULTS" write "$GLOBAL_DOMAIN" "$key" -bool "$wanted"

  if is_dry_run; then
    log "would set $description"
    return 0
  fi

  current="$("$DEFAULTS" read "$GLOBAL_DOMAIN" "$key" 2>/dev/null || true)"
  if [ "$current" != "$wanted_value" ]; then
    die "the text-input default did not persist: $key"
  fi
  log "set $description"
}

# Substituting a period for a double space inserts a character the typist never
# pressed. It is particularly hard to attribute while switching between Korean
# and English, because the insertion is silent and only surfaces later in the
# text, so it is turned off rather than left to the machine default.
apply_boolean_default NSAutomaticPeriodSubstitutionEnabled false \
  'double-space period substitution off'

# The remaining substitutions rewrite characters that were typed deliberately.
# Curly quotes and en dashes are wrong in anything read back as literal text —
# code, configuration, shell commands, commit messages — and capitalising the
# first word of a sentence corrupts identifiers that are meant to be lowercase.
apply_boolean_default NSAutomaticCapitalizationEnabled false \
  'automatic capitalization off'
apply_boolean_default NSAutomaticQuoteSubstitutionEnabled false \
  'smart quote substitution off'
apply_boolean_default NSAutomaticDashSubstitutionEnabled false \
  'smart dash substitution off'
apply_boolean_default NSAutomaticSpellingCorrectionEnabled false \
  'automatic spelling correction off'

log 'text input defaults applied; applications read them when next launched'
