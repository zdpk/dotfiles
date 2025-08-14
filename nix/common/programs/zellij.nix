{ config, pkgs, ... }:

{
  programs.zellij = {
    enable = true;
    
    # Zellij configuration
    settings = {
      # Key bindings configuration
      keybinds = {
        shared = {
          bind = [
            {
              key = [ "Alt h" "Alt Left" ];
              action = "MoveFocusOrTab Left";
            }
            {
              key = [ "Alt j" "Alt Down" ];
              action = "MoveFocusOrTab Down";
            }
            {
              key = [ "Alt k" "Alt Up" ];
              action = "MoveFocusOrTab Up";
            }
            {
              key = [ "Alt l" "Alt Right" ];
              action = "MoveFocusOrTab Right";
            }
            {
              key = [ "Alt m" ];
              action = "ToggleFloatingPanes";
            }
          ];
        };
      };
    };
  };
}