{ config, pkgs, lib, ... }:

{
  # Import all program configurations
  imports = [
    ./packages.nix
    ./programs/helix.nix
    ./programs/fish.nix
    ./programs/bash.nix
    ./programs/wezterm.nix
    ./programs/ghostty.nix
    ./programs/zellij.nix
    ./programs/git.nix
  ];

  # Basic Home Manager configuration
  home = {
    username = "x";
    stateVersion = "24.05";
    
    # Environment variables
    sessionVariables = {
      EDITOR = "hx";
      BROWSER = "open";
    };
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # XDG configuration (mainly for Linux)
  xdg = {
    enable = true;
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    cacheHome = "${config.home.homeDirectory}/.cache";
  };

  # Fonts configuration
  fonts.fontconfig.enable = true;
}