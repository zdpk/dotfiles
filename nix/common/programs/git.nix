{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    
    # Basic Git configuration
    # Note: These should be customized per user
    userName = "Your Name";
    userEmail = "your.email@example.com";
    
    # Git configuration options
    extraConfig = {
      # Core settings
      core = {
        editor = "hx";
        autocrlf = false;
        safecrlf = true;
        # Use system credential helper on macOS
        # credentialHelper = "osxkeychain"; # This will be set in system-specific configs
      };
      
      # Push settings
      push = {
        default = "simple";
        autoSetupRemote = true;
      };
      
      # Pull settings
      pull = {
        rebase = true;
      };
      
      # Branch settings
      branch = {
        autosetupmerge = "always";
        autosetuprebase = "always";
      };
      
      # Color settings
      color = {
        ui = "auto";
        branch = "auto";
        diff = "auto";
        status = "auto";
      };
      
      # Alias settings
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        di = "diff";
        lo = "log --oneline";
        lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      };
      
      # Merge tool settings
      merge = {
        tool = "vimdiff";
      };
      
      # Diff settings
      diff = {
        tool = "vimdiff";
      };
      
      # Init settings
      init = {
        defaultBranch = "main";
      };
    };
    
    # Git ignore global patterns
    ignores = [
      # macOS
      ".DS_Store"
      ".AppleDouble"
      ".LSOverride"
      
      # IDE
      ".vscode/"
      ".idea/"
      "*.swp"
      "*.swo"
      "*~"
      
      # Logs
      "*.log"
      "npm-debug.log*"
      
      # Runtime data
      "pids"
      "*.pid"
      "*.seed"
      "*.pid.lock"
      
      # Coverage directory used by tools like istanbul
      "coverage/"
      
      # node_modules
      "node_modules/"
      
      # Build outputs
      "dist/"
      "build/"
      "*.o"
      "*.so"
      
      # Temporary files
      "tmp/"
      "temp/"
      ".cache/"
    ];
  };
}