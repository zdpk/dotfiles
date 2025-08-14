{ config, pkgs, lib, ... }:

{
  # macOS-specific system configuration

  # System packages that should be installed system-wide
  environment.systemPackages = with pkgs; [
    # Add any system-wide packages here
  ];

  # Homebrew integration for macOS-specific apps
  homebrew = {
    enable = true;
    
    # Applications to install from Mac App Store
    masApps = {
      # Add Mac App Store applications here if needed
      # "Xcode" = 497799835;
    };
    
    # Homebrew casks (GUI applications)
    casks = [
      "ghostty"  # Install Ghostty via Homebrew since it's not in nixpkgs yet
    ];
    
    # Homebrew formulas (CLI tools)
    brews = [
      # Add any Homebrew-specific CLI tools here
    ];
  };

  # System preferences
  system = {
    # macOS system defaults
    defaults = {
      dock = {
        autohide = true;
        show-recents = false;
        launchanim = true;
        mouse-over-hilite-stack = true;
        orientation = "bottom";
        tilesize = 48;
      };
      
      finder = {
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        QuitMenuItem = true;
      };
      
      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };
      
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false;
        
        # Key repeat settings
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
        
        # Menu bar clock
        "com.apple.menuextra.clock" = {
          DateFormat = "EEE MMM d  h:mm a";
        };
      };
    };
    
    # Keyboard settings
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };
  };

  # Services
  services = {
    # Add macOS-specific services here
    nix-daemon.enable = true;
  };

  # Users configuration
  users.users.x = {
    name = "x";
    home = "/Users/x";
  };

  # Nix settings
  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "@admin" ];
    };
  };

  # System version
  system.stateVersion = 4;

  # Allow unfree packages (needed for some casks/apps)
  nixpkgs.config.allowUnfree = true;
}