{ config, pkgs, lib, ... }:

{
  programs.fish = {
    enable = true;
    
    # Fish configuration
    interactiveShellInit = ''
      # BASH loading sequence comments (kept for reference)
      # BASH
      # (Login Shell)
      # 1. /etc/profile
      # 2. ~/.bash_profile or ~/.bash_login or ~/.profile -> ~/.bashrc(indirectly)
      # (Non-login Shell or Interactive Shell)
      # 1. /etc/bash.bashrc
      # 2. ~/.bashrc
      # Logout
      # 1. ~/.bash_logout

      # FISH
      # 1. /etc/fish/config.fish
      # 2. ~/.config/fish/config.fish
      
      # Load bash configurations using bass plugin
      if status is-interactive
        bass source ~/.bashrc
      end
    '';
    
    # Fish plugins
    plugins = [
      {
        name = "bass";
        src = pkgs.fishPlugins.bass.src;
      }
    ];
    
    # Shell aliases (equivalent to bash alias.sh)
    shellAliases = {
      hx = "helix";
    };
    
    # Functions for global fish configuration (login shell)
    functions = {
      # Function to handle login shell initialization
      __fish_login_init = {
        body = ''
          if status is-login
            # Source system profile using bass
            bass source /etc/profile
            
            # Source profile.d scripts
            for file in /etc/profile.d/*.sh
              if not test -e $file
                echo "not found $file(config.fish)"
                exit 1
              end
              bass source $file
              if test $status -ne 0
                echo "failed to source $file(config.fish)"
                exit 1
              end
            end
          end
        '';
        onEvent = "fish_prompt";
      };
    };
  };
  
  # Create bash configuration for compatibility
  programs.bash = {
    enable = true;
    
    # Source all .sh files from bash config directory
    initExtra = ''
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
  };
  
  # Create the bash config directory and alias file
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
    '';
    executable = true;
  };
}