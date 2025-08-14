{ config, pkgs, ... }:

{
  programs.helix = {
    enable = true;
    
    settings = {
      theme = "github_dark_dimmed";
      
      editor = {
        # Show rulers at column 80 and 120
        rulers = [ 80 120 ];
        # Use relative line numbers
        line-number = "relative";
        mouse = false;
        # Force the theme to show colors
        true-color = true;
        # Highlight all lines with a cursor
        cursorline = true;
        # Show currently open buffers, only when more than one exists
        bufferline = "multiple";
        
        # Quick auto completion trigger
        completion-trigger-len = 0;
        idle-timeout = 0;
        
        # Indent guides configuration
        indent-guides = {
          render = true;
          character = "╎";
          skip-levels = 1;
        };
        
        # LSP configuration
        lsp = {
          auto-signature-help = true;
          display-messages = true;
        };
        
        # Status line configuration
        statusline = {
          left = [ "mode" "spinner" "version-control" "file-name" ];
        };
        
        # Cursor shape configuration
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
      };
    };
    
    # Key bindings
    keys = {
      insert = {
        "C-space" = "completion";
      };
      
      normal = {
        "A-k" = "keep_selections";
        "S-n" = [ ":o" "insert_register" "select_all" ];
        "A-y" = "yank_main_selection_to_clipboard";
        "A-Y" = "yank_main_selection_to_clipboard";
        "A-p" = "paste_clipboard_after";
        "A-P" = "paste_clipboard_before";
        "C-f" = [
          ":new"
          ":insert-output lf-pick"
          "select_all"
          "split_selection_on_newline"
          "goto_file"
          "goto_last_modified_file"
          ":buffer-close!"
        ];
      };
    };
    
    # Language configurations
    languages = {
      language = [
        {
          name = "rust";
          auto-format = true;
          language-servers = [ "rust-analyzer" ];
          formatter = {
            command = "rustfmt";
            args = [ "--edition" "2021" ];
          };
        }
        {
          name = "javascript";
          auto-format = true;
          formatter = {
            command = "prettier";
            args = [ "--parser" "javascript" ];
          };
        }
        {
          name = "typescript";
          auto-format = true;
          formatter = {
            command = "prettier";
            args = [ "--parser" "typescript" ];
          };
        }
        {
          name = "tsx";
          auto-format = true;
          formatter = {
            command = "prettier";
            args = [ "--parser" "typescript" ];
          };
        }
        {
          name = "jsx";
          auto-format = true;
          formatter = {
            command = "prettier";
            args = [ "--parser" "typescript" ];
          };
        }
        {
          name = "json";
          auto-format = true;
          formatter = {
            command = "prettier";
            args = [ "--parser" "json" ];
          };
        }
        {
          name = "html";
          auto-format = true;
          formatter = {
            command = "prettier";
            args = [ "--parser" "html" ];
          };
        }
        {
          name = "css";
          auto-format = true;
          formatter = {
            command = "prettier";
            args = [ "--parser" "css" ];
          };
        }
        {
          name = "bash";
          auto-format = true;
          formatter = {
            command = "shfmt";
            args = [ "-i" "2" "-ci" ];
          };
        }
        {
          name = "c";
          auto-format = true;
          formatter = {
            command = "clang-format";
            args = [ "--style=file" ];
          };
        }
      ];
    };
  };
}