{ config, pkgs, lib, ... }:

{
  programs.wezterm = {
    enable = true;
    
    extraConfig = ''
      -- Pull in the wezterm Api
      local wezterm = require 'wezterm'

      -- This will hold the config
      local config = wezterm.config_builder()
      local act = wezterm.action

      -- Basic configuration
      config.color_scheme = 'GitHub Dark'
      config.disable_default_key_bindings = true

      -- Font configuration
      config.freetype_load_target = "Light"
      config.font = wezterm.font_with_fallback({
        { family = "GeistMono Nerd Font", weight = "Bold" },
        { family = "JetBrains Mono", weight = "Bold" }
      })
      config.font_size = 17.5

      -- Tab and window configuration
      config.use_fancy_tab_bar = true
      config.hide_tab_bar_if_only_one_tab = true
      config.enable_scroll_bar = true

      -- Confirmation before closing
      config.window_close_confirmation = 'AlwaysPrompt'

      -- Window frame styling
      config.window_frame = {
        active_titlebar_bg = "#333",
      }

      -- Key bindings
      config.keys = {
        {
          key = 'q',
          mods = 'CMD',
          action = act.CloseCurrentTab { confirm = true },
        },
        {
          key = 'n',
          mods = 'CMD',
          action = act.SpawnWindow,
        },
        {
          key = '+',
          mods = 'CMD',
          action = act.IncreaseFontSize,
        },  
        {
          key = '-',
          mods = 'CMD',
          action = act.DecreaseFontSize,
        },  
        {
          key = 'c',
          mods = 'CMD',
          action = act.CopyTo 'Clipboard',
        },  
        {
          key = 'v',
          mods = 'CMD',
          action = act.PasteFrom 'Clipboard',
        },
      }

      -- Window appearance
      config.window_decorations = 'RESIZE'
      config.macos_window_background_blur = 80
      config.window_padding = {
        left = 20,
        right = 20,
        top = 20,
        bottom = 20,
      }
      config.window_background_opacity = 0.8

      return config
    '';
  };
}