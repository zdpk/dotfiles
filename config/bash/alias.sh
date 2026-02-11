#!/usr/bin/env bash

set_alias_checked() {
    local CMD="$1"
    local ALIAS="$2"

    if ! command -v "$CMD" &>/dev/null; then
        return 0
    fi

    alias "$ALIAS"="$CMD"
}

set_alias_checked helix hx

alias ccd='claude --dangerously-skip-permissions'
