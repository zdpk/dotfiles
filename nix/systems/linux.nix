{ config, pkgs, lib, ... }:

{
  # Linux-specific system configuration
  
  # System packages for Linux
  home.packages = with pkgs; [
    # Linux-specific packages
    ghostty  # Available in nixpkgs for Linux
    
    # Additional Linux utilities
    xclip    # For clipboard operations
    wl-clipboard  # For Wayland clipboard
  ];

  # XDG settings for Linux
  xdg = {
    enable = true;
    
    # MIME type associations
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/plain" = [ "helix.desktop" ];
        "application/json" = [ "helix.desktop" ];
        "text/x-shellscript" = [ "helix.desktop" ];
      };
    };
  };

  # Font configuration for Linux
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      monospace = [ "FiraCode Nerd Font" "JetBrains Mono" ];
      sansSerif = [ "Inter" "Liberation Sans" ];
      serif = [ "Liberation Serif" ];
    };
  };

  # Session variables specific to Linux
  home.sessionVariables = {
    # Wayland-specific variables
    NIXOS_OZONE_WL = "1";  # Enable Wayland for Electron apps
    MOZ_ENABLE_WAYLAND = "1";  # Enable Wayland for Firefox
    
    # XDG directories
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_CACHE_HOME = "$HOME/.cache";
  };
  
  # Services specific to Linux
  services = {
    # GPG agent
    gpg-agent = {
      enable = true;
      defaultCacheTtl = 1800;
      enableSshSupport = true;
    };
  };

  # Programs with Linux-specific configurations
  programs = {
    # Git configuration with Linux-specific settings
    git = {
      extraConfig = {
        core = {
          # Use different credential helper for Linux
          credentialHelper = "cache --timeout=3600";
        };
      };
    };
    
    # GPG
    gpg = {
      enable = true;
    };
  };
}