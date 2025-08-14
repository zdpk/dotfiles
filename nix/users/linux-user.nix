{ config, pkgs, lib, ... }:

{
  imports = [
    ../common/home.nix
    ../systems/linux.nix
  ];

  # Linux-specific home configuration
  home = {
    homeDirectory = "/home/x";
    
    # Linux-specific session variables
    sessionVariables = {
      # Use cache credential helper for Git
      GIT_CREDENTIAL_HELPER = "cache --timeout=3600";
    };
  };

  # Linux-specific programs configuration
  programs = {
    # Fish shell with Linux-specific paths
    fish = {
      shellInit = ''
        # Add user's local bin to PATH
        fish_add_path $HOME/.local/bin
        
        # Add Nix to PATH for non-NixOS systems
        if test -d $HOME/.nix-profile/bin
          fish_add_path $HOME/.nix-profile/bin
        end
        
        # Add system paths
        fish_add_path /usr/local/bin
        fish_add_path /usr/bin
        fish_add_path /bin
      '';
    };
  };

  # Create system-specific configuration files for Linux
  home.file = {
    # Fish global configuration for Linux
    ".config/fish/global_config_linux.fish" = {
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
            # Source system profile if available
            if test -f /etc/profile
                bass source /etc/profile
            end

            # Source profile.d scripts
            if test -d /etc/profile.d
                for file in /etc/profile.d/*.sh
                    if test -f $file
                        bass source $file
                    end
                end
            end
        end
      '';
    };
  };

  # Linux-specific services
  systemd.user = {
    # Enable user services
    # startServices = "sd-switch";
  };
}