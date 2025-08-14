{ config, pkgs, lib, ... }:

{
  imports = [
    ../common/home.nix
  ];

  # macOS-specific home configuration
  home = {
    homeDirectory = "/Users/x";
    
    # macOS-specific session variables
    sessionVariables = {
      # Use macOS credential helper for Git
      GIT_CREDENTIAL_HELPER = "osxkeychain";
    };
  };

  # macOS-specific programs configuration
  programs = {
    # Git configuration for macOS
    git = {
      extraConfig = {
        core = {
          credentialHelper = "osxkeychain";
        };
      };
    };
    
    # Fish shell with macOS-specific paths
    fish = {
      shellInit = ''
        # Add Homebrew to PATH on Apple Silicon Macs
        if test -d /opt/homebrew/bin
          fish_add_path /opt/homebrew/bin
          fish_add_path /opt/homebrew/sbin
        end
        
        # Add MacPorts to PATH if it exists
        if test -d /opt/local/bin
          fish_add_path /opt/local/bin
          fish_add_path /opt/local/sbin
        end
        
        # Add Nix to PATH
        if test -d /nix/var/nix/profiles/default/bin
          fish_add_path /nix/var/nix/profiles/default/bin
        end
      '';
    };
  };

  # macOS-specific packages
  home.packages = with pkgs; [
    # macOS-specific utilities
  ] ++ lib.optionals stdenv.isDarwin [
    # Add macOS-specific packages here
  ];

  # Create system-specific configuration files
  home.file = {
    # Fish global configuration for macOS (requires sudo)
    # Note: This needs to be manually linked with sudo
    ".config/fish/global_config_darwin.fish" = {
      text = ''
        # BASH loading sequence (for reference)
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

        if status is-login
            bass source /etc/profile

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
    };
  };

  # macOS-specific services
  launchd.agents = {
    # Add any user-specific launchd agents here if needed
  };
}