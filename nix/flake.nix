{
  description = "Cross-platform dotfiles using Nix and Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs: {
    # macOS configurations
    darwinConfigurations = {
      "default" = darwin.lib.darwinSystem {
        system = "aarch64-darwin"; # Change to x86_64-darwin if needed
        modules = [
          ./systems/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.x = import ./users/darwin-user.nix;
            };
          }
        ];
      };
    };

    # Linux configurations
    homeConfigurations = {
      "x@linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./users/linux-user.nix
        ];
      };
    };

    # Standalone Home Manager configurations (for existing systems)
    homeConfigurations = {
      "x@macos" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        modules = [
          ./users/darwin-user.nix
        ];
      };
      "x@linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./users/linux-user.nix
        ];
      };
    };
  };
}