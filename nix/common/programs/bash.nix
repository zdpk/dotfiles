{ config, pkgs, ... }:

{
  programs.bash = {
    enable = true;
    
    # Bash configuration with error handling
    initExtra = ''
      set -euo pipefail
      
      # Source all bash configuration files
      for file in ~/.config/bash/*.sh; do
        if [ -f "$file" ]; then
          source "$file"
        fi
      done
    '';
    
    # Shell aliases
    shellAliases = {
      hx = "helix";
    };
    
    # Bash-specific environment variables
    sessionVariables = {
      # Add any bash-specific variables here
    };
  };
  
  # Create the bash config directory and files
  home.file.".config/bash/alias.sh" = {
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      set_alias_checked() {
          local CMD="$1"
          local ALIAS="$2"

          if ! command -v "$CMD" &>/dev/null; then
              echo "failed to set alias. command '$CMD' not found"
              return 1
          fi

          alias "$ALIAS"="$CMD"
      }

      set_alias_checked helix hx

      # Commented out soft_rm alias for safety
      # source "${DOTFILES_DIR}/scripts/soft_rm.sh"
      # alias rm="scripts/soft_rm.sh"
    '';
    executable = true;
  };
}