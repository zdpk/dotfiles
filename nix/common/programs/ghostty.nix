{ config, pkgs, lib, ... }:

{
  # Ghostty configuration
  # Note: Ghostty may not be available in nixpkgs on all platforms
  # On macOS, it's typically installed via the official app
  
  home.file.".config/ghostty/config" = {
    text = ''
      #################################################
      # font
      #################################################
      font-family = "FiraCode Nerd Font", "Apple SD Gothic Neo"
      font-family-bold = "FiraCode Nerd Font Bold"
      font-synthetic-style = true
      font-size = 17
      adjust-cell-width = 0%

      #################################################
      # window
      #################################################
      window-theme = dark
      window-colorspace = display-p3
      window-padding-x = 10,10
      window-padding-y = 10,10

      #################################################
      # shell-integration
      #################################################
      shell-integration = none
      shell-integration-features = cursor, sudo, no-title

      #################################################
      # mouse
      #################################################
      mouse-scroll-multiplier = 0.7

      # Background and theme
      background-opacity = 0.7
      background-blur = true
      theme = /Applications/Ghostty.app/Contents/Resources/ghostty/themes/tokyonight

      # Key bindings
      keybind = shift+enter=text:\n
      keybind = ctrl+d=scroll_page_down
      keybind = ctrl+u=scroll_page_up
    '';
  };
}