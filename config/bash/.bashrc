#!/usr/bin/env bash

for file in ~/.config/bash/*.sh; do
    source "$file"
done

# Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi
