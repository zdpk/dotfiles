{ pkgs, lib, stdenv, ... }:

{
  home.packages = with pkgs; [
    # Core development tools
    git
    helix
    
    # Terminal and multiplexers
    wezterm
    zellij
    
    # Shell and utilities
    fish
    bash
    
    # Fonts
    (nerdfonts.override { fonts = [ "FiraCode" "GeistMono" "JetBrainsMono" ]; })
    
    # Development utilities
    ripgrep
    fd
    bat
    eza
    
    # Fish plugins and tools
    fishPlugins.bass
    
    # Platform-specific packages
  ] ++ lib.optionals stdenv.isDarwin [
    # macOS specific packages
  ] ++ lib.optionals stdenv.isLinux [
    # Linux specific packages
    ghostty
  ];
}