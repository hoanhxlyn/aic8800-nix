{
  description = "NixOS driver and module for AIC8800D80 WiFi 6 chipset";

  nixConfig = {
    extra-substituters = "https://aic8800-nix.cachix.org";
    extra-trusted-public-keys = "aic8800-nix.cachix.org-1:prQpnv5lMiN+SlLsuOt+vdf2EkBInFqE1rMTZf/JsdE=";
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    # Support common Linux systems
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    # Helper to generate attributes for all systems
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Helper to get nixpkgs for a system
    nixpkgsFor = system: import nixpkgs {inherit system;};
  in {
    # Kernel module packages for each system
    packages = forAllSystems (
      system: let
        pkgs = nixpkgsFor system;
      in {
        # Driver for the newest kernel (Linux 7.x only)
        default = pkgs.linuxPackages_latest.callPackage ./default.nix {};

        # Alias kept for compatibility
        latest = pkgs.linuxPackages_latest.callPackage ./default.nix {};
      }
    );

    # NixOS module for system integration
    nixosModules.default = import ./module.nix;

    # Alias for convenience
    nixosModules.aic8800 = self.nixosModules.default;

    # Development shell for testing and building
    devShells = forAllSystems (
      system: let
        pkgs = nixpkgsFor system;
      in {
        default = pkgs.mkShell {
          name = "aic8800-dev";

          nativeBuildInputs = with pkgs; [
            # Kernel build dependencies
            gnumake
            gcc
            pkg-config

            # For testing
            linuxPackages_latest.kernel.dev
            kmod

            # Useful tools
            git
            nix-output-monitor
          ];

          shellHook = ''
            echo "AIC8800D80 WiFi Driver Development Environment"
            echo "=============================================="
            echo ""
            echo "Available commands:"
            echo "  nix build .#default         - Build driver for the latest kernel"
            echo "  nix build .#latest          - Same as .#default"
            echo "  nixos-rebuild switch        - Install on NixOS"
            echo ""
            echo "Kernel version: ${pkgs.linuxPackages_latest.kernel.version}"
          '';
        };
      }
    );

    # Formatter for Nix files (use alejandra or nixpkgs-fmt)
    formatter = forAllSystems (system: (nixpkgsFor system).alejandra);
  };
}
