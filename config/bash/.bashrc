#!/usr/bin/env bash

for file in ~/.config/bash/*.sh; do
    source "$file"
done

# Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi


# Added by Antigravity CLI installer
export PATH="/Users/x/.local/bin:$PATH"
